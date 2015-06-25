//
//  HttpClient.swift
//  HttpClient
//
//  Created by Gforce on 6/22/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit
enum httpMethod{
    case Get
    case Post
    case Put
    case Delete
    case Head
}
private enum HttpClientRequestState{
    case Ready
    case Executing
    case Finished
}
// 用户设定一些Option
struct HttpClientOption {
    static let TimeOut = "TimeOut"   // NSNumber 的Int类型  不然无效
    static let UserAgent = "UserAgent"  //String 类型
    static let CachePolicy = "CachePolicy" //当使用缓存时设置CachePolicy无效,``____`` 缓存不靠谱,我要 自己写缓存
    static let SendParametersAsJSON  = "SendParametersAsJSON"   //NSNumber 的Bool类型  不然无效
    static let UserName = "UserName"
    static let Password = "Password"
    static let SavePath = "SavePath"  // 要是个完整路径,不然会报错
    static let UseFileName = "UseFileName"   //NSNumber 的Bool类型  不然无效
}
// 没有继承于NSObject，所以没有dealloc方法用
class HttpClient:NSOperation,NSURLConnectionDataDelegate{
    //private filed
    private var _httpClientRequestState:HttpClientRequestState = HttpClientRequestState.Ready
    private var httpClientRequestState:HttpClientRequestState    {
        get{
            return _httpClientRequestState  //这里暂时用不了线程同步
        }
       set{
            objc_sync_enter(self)
            willChangeValueForKey("httpClientRequestState")
            _httpClientRequestState = newValue
            didChangeValueForKey("httpClientRequestState")
            objc_sync_exit(self)
        }
    }
    private static var taskCount:UInt = 0
    private static var GlobalTimeoutInterval:NSTimeInterval = 20
    private static var GlobalUserAgent:String = "HttpClient" //need check
    private static var GlobalCachePolicy:NSURLRequestCachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy
    private static var GlobalNeedSendParametersAsJSON = false
    private static var GlobalUserName:String?
    private static var GlobalPassword:String?
    private static let sharedQuene:NSOperationQueue = NSOperationQueue()
    private class var operationQueue:NSOperationQueue{
        get{
            return HttpClient.sharedQuene
        }
    }
    private static var cacheKeyDict:Dictionary<String,NSDate> = Dictionary<String,NSDate>()
    private class var sharedCacheKeyDict:Dictionary<String,NSDate>{
        set{
            println("before set")
            for (key,value) in HttpClient.cacheKeyDict{
                println("key:\(key) and value:\(value)")
            }
            HttpClient.cacheKeyDict = newValue
            println("after set")
            for (key,value) in HttpClient.cacheKeyDict{
                println("key:\(key) and value:\(value)")
            }
        }
        get{
            return HttpClient.cacheKeyDict
        }
    }
    
    private var httpHeaderFields:Dictionary<String,AnyObject>? //现在还没有用到，需要研究怎么用
    private var operationRequest:NSMutableURLRequest?
    private var operationData:NSMutableData?
    private var operationFileHandle:NSFileHandle?
    private var operationConnection:NSURLConnection?
    private var operationParameters:Dictionary<String,AnyObject>?
    private var operationURLResponse:NSHTTPURLResponse?
    private var operationSavePath:String?
    private var operationRunLoop:CFRunLoopRef?
    private var cancelToken:String?
    private var isCacheInValid:Bool{
        get{
            if let key = operationRequest!.URL?.absoluteString?.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
            {
                if let expireDate = HttpClient.sharedCacheKeyDict[key]
                {
                    if NSDate().compare(expireDate) == NSComparisonResult.OrderedDescending{
                        println("key:\(key)的缓存已经失效")
                        return true
                    }
                    else
                    {
                        return false
                    }
                }
            }
            return true

        }
    }
    private var cacheTime:Int = 0
    private var backgroundTaskIdentifier:UIBackgroundTaskIdentifier?
    private var saveDataDispatchQueue:dispatch_queue_t
    private var saveDataDispatchGroup:dispatch_group_t
    private var operationCompletion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()
    private var operationProgress:((progress:Float)->())?
    private var queryParameters:Dictionary<String,AnyObject>?  //这个是如果使用Post上传，但是还是要在Url后面添加一些参数时的字段
    private var operationRequestOptions:Dictionary<String,AnyObject>? //这个是设置单独一次请求的相关参数，又如超时，缓存方式等
    private var requestPath:String?  //这也是一种取消请求的方法，需要研究
    private var _timeoutTimer:NSTimer?
    private var timeoutTimer:NSTimer?{
        get{
            return _timeoutTimer
        }
        set{
            if _timeoutTimer != nil{
                _timeoutTimer?.invalidate()
                _timeoutTimer = nil
            }
            _timeoutTimer = newValue
        }
    }
    private var expectedContentLength:Float = 0
    private var receivedContentLength:Float = 0
    private var configDict:Dictionary<String,AnyObject>?
    private var userAgent:String?   //这个可用一个option来设定 作为单次请求的参数
    private var timeoutInterval:NSTimeInterval //这个可以用一个Option来设定，作为单次请求的参数
    private var cachePolicy:NSURLRequestCachePolicy //这个可以用一个Option来设定，作为单次请求的参数
    private var sendParametersAsJSON:Bool?
    private var Username:String?
    private var Password:String?
    private var useFileName:Bool = false //是否使用原始文件名上传，默认为否
    private var isFinished:Bool{
        get{
            return httpClientRequestState == HttpClientRequestState.Finished}
    }
    private var isExecuting:Bool{
        get{
            return httpClientRequestState == HttpClientRequestState.Executing
        }
    }
    // MARK: public func 
    // Global 的方法最好在APPDelegate设置,确保在任何调用前设置
    static func setGlobalTimeoutInterval(timeInterval:NSTimeInterval){
        HttpClient.GlobalTimeoutInterval = timeInterval
    }
    
    static func setGlobalUserAgent(userAgent:String){
        HttpClient.GlobalUserAgent = userAgent
    }
    
    static func setGlobalCachePolicy(cachePolicy:NSURLRequestCachePolicy){
        HttpClient.GlobalCachePolicy = cachePolicy
    }

    static func setGlobalNeedSendParametersAsJSON(sendParametersAsJSON:Bool){
        HttpClient.GlobalNeedSendParametersAsJSON = sendParametersAsJSON
    }
    
    static func setGlobalUsername(userName:String){
        HttpClient.GlobalUserName = userName
    }
    
    static func setGlobalPassword(pass:String){
        HttpClient.GlobalPassword = pass
    }
    

    
    static func cancelRequestsWithPath(path:String){
        for queue in HttpClient.sharedQuene.operations{
            if let httpClient = queue as? HttpClient{
                if let  requestPath = httpClient.requestPath
                {
                    if requestPath == path{
                        httpClient.cancel()
                    }
                }
            }
        }
    }
    
    static func cancelAllRequests(){
        HttpClient.sharedQuene.cancelAllOperations()
    }
    
    static func cancelRequestWithIndentity(cancelToken:String){
        for queue in HttpClient.sharedQuene.operations{
            if let httpClient = queue as? HttpClient{
                if let  token = httpClient.cancelToken
                {
                    if token == cancelToken{
                        httpClient.cancel()
                    }
                }
            }
        }
    }
    
    static func clearUrlCache(url:String){
        HttpClient.sharedCacheKeyDict.removeValueForKey(url)
        var path = HttpClient.getCacheFileName(url)
        NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
    }
    
    static func clearCache(){
        HttpClient.sharedCacheKeyDict.removeAll(keepCapacity: false)
        var cachePath: AnyObject? = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true).first
        cachePath = (cachePath as! NSString).stringByAppendingPathComponent("HttpClientCaches") as String
        NSFileManager.defaultManager().removeItemAtPath(cachePath as! String, error: nil)
    }
    
    static func get(address:String,parameters:Dictionary<String,AnyObject>?,cache:Int,cancelToken:String?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) ->HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Get, parameters: parameters, cache: cache, cancelToken: cancelToken, queryPara:nil, requestOptions:nil,headerFields:nil, progress: nil, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func get(address:String,parameters:Dictionary<String,AnyObject>?, cache:Int,cancelToken:String?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) ->HttpClient {
        var httpClient = HttpClient(address: address, method: httpMethod.Get, parameters: parameters, cache: cache, cancelToken: cancelToken, queryPara:nil, requestOptions:requestOptions,headerFields:headerFields, progress: progress, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func Post(address:String,parameters:Dictionary<String,AnyObject>?,cancelToken:String?, complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) ->HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Post, parameters: parameters, cache: 0, cancelToken: cancelToken, queryPara:nil, requestOptions:nil,headerFields:nil, progress: nil, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func Post(address:String,parameters:Dictionary<String,AnyObject>?,cancelToken:String?,queryPara:Dictionary<String,AnyObject>?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Post, parameters: parameters, cache: 0,  cancelToken: cancelToken, queryPara:nil, requestOptions:nil,headerFields:nil, progress: nil, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func Post(address:String,parameters:Dictionary<String,AnyObject>?,cancelToken:String?,queryPara:Dictionary<String,AnyObject>?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Post, parameters: parameters, cache: 0, cancelToken: cancelToken, queryPara:queryPara, requestOptions:requestOptions,headerFields:headerFields, progress: progress, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func Delete(address:String,parameters:Dictionary<String,AnyObject>?,cancelToken:String?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Delete, parameters: parameters, cache: 0,cancelToken: cancelToken, queryPara:nil, requestOptions:nil,headerFields:nil, progress: nil, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }

    static func Put(address:String,parameters:Dictionary<String,AnyObject>?,cancelToken:String?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Put, parameters: parameters, cache: 0, cancelToken: cancelToken, queryPara:nil, requestOptions:requestOptions,headerFields:headerFields, progress: progress, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }

    static func Head(address:String,parameters:Dictionary<String,AnyObject>?,cancelToken:String?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Head, parameters: parameters, cache: 0, cancelToken: cancelToken, queryPara:nil, requestOptions:requestOptions,headerFields:headerFields, progress: progress, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    // MARK: private func
    private init(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,cancelToken:String?,queryPara:Dictionary<String,AnyObject>?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()){
        operationCompletion = complettion
        operationProgress = progress
        operationParameters = parameters
        queryParameters = queryPara
        timeoutInterval = HttpClient.GlobalTimeoutInterval
        sendParametersAsJSON = HttpClient.GlobalNeedSendParametersAsJSON
        httpHeaderFields = headerFields
        self.cancelToken = cancelToken
        saveDataDispatchGroup = dispatch_group_create()
        saveDataDispatchQueue = dispatch_queue_create("HttpClient", DISPATCH_QUEUE_SERIAL)
        
        if let url  = NSURL(string: address){
            operationRequest = NSMutableURLRequest(URL: url)
        }
        else{
             assert(false, "you pass a invalid url")  //非法的Url
            
        }
        if cache > 0{
            cacheTime = cache
            
        }

        switch(method){
            case .Get: operationRequest?.HTTPMethod = "GET"
            case .Post: operationRequest?.HTTPMethod = "POST"
            case .Put: operationRequest?.HTTPMethod = "PUT"
            case .Delete: operationRequest?.HTTPMethod = "DELETE"
            case .Head: operationRequest?.HTTPMethod = "HEAD"
            default:operationRequest?.HTTPMethod = "GET"
        }
        Username = HttpClient.GlobalUserName
        Password = HttpClient.GlobalPassword
        cachePolicy = HttpClient.GlobalCachePolicy
        if requestOptions != nil{
            for (key,value) in requestOptions!{
                switch key{
                case HttpClientOption.SavePath: operationSavePath = value as? String
                case HttpClientOption.CachePolicy:  if let policy = value as? NSURLRequestCachePolicy{
                    cachePolicy = policy
                    }
                case HttpClientOption.Password:  Password = value as? String
                case HttpClientOption.SendParametersAsJSON:sendParametersAsJSON = value as? Bool
                case HttpClientOption.TimeOut:                    if let timeInterval = value as? NSTimeInterval{
                    timeoutInterval = timeInterval
                    }
                case HttpClientOption.UserAgent:    userAgent = value as? String
                case HttpClientOption.UserName:Username = value as? String
                case HttpClientOption.UseFileName:                    if let isUse = value as? Bool{
                    useFileName = isUse
                    }
                default: break
                }
            }
        }
        super.init()
        httpClientRequestState = HttpClientRequestState.Ready
        if method != httpMethod.Post && operationSavePath == nil{
            operationRequest?.HTTPShouldUsePipelining = true
        }
        //这个要放在super.init()后面才行
        //这个地方以后需要研究
    }
    
    override func start() {
        if cancelled{
            finish()
            return
        }
        backgroundTaskIdentifier = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({ () -> Void in
            if self.backgroundTaskIdentifier! != UIBackgroundTaskInvalid{
                UIApplication.sharedApplication().endBackgroundTask(self.backgroundTaskIdentifier!)
                self.backgroundTaskIdentifier = UIBackgroundTaskInvalid
            }
        })
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.increaseTaskCount()
        })
        if operationParameters != nil{             //添加参数
            addParametersToRequest(operationParameters!)
        }
        if userAgent != nil{
            operationRequest?.setValue(userAgent!, forHTTPHeaderField: "User-Agent")
        }
        else
        {
            operationRequest?.setValue(HttpClient.GlobalUserAgent, forHTTPHeaderField: "User-Agent")
        }
        willChangeValueForKey("isExecuting") //改变状态
        httpClientRequestState = HttpClientRequestState.Executing
        didChangeValueForKey("isExecuting")
        if operationSavePath != nil{  //如果需要保存数据
            if   NSFileManager.defaultManager().createFileAtPath(operationSavePath!, contents: nil, attributes: nil){
                operationFileHandle = NSFileHandle(forWritingAtPath: operationSavePath!)
            }
            else{
                assert(false, "error path")
                var exception = NSException(name: "Invalid path", reason: "you provide a invalid path", userInfo: [NSInvalidArgumentException:operationSavePath!])
               exception.raise()
            }
        }
        operationData = NSMutableData() //即使保存数据,也是要加载的
        timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutInterval, target: self, selector: "requestTimeout", userInfo: nil, repeats: false)
        operationRequest?.timeoutInterval = timeoutInterval
        operationRequest?.cachePolicy = cachePolicy
        setHeadField()
        signRequestWithUsername()
        //检查有没有设置缓存 
        if cacheTime > 0{
            //如果有缓存,检查有没有失效
            if isCacheInValid{  //如果 失效 , 什么也没干
                
            }
            else{ //没有失效,就不再请求,直接从Document获取数据返回
                var filePath = getCacheFileName()
                if NSFileManager.defaultManager().fileExistsAtPath(filePath){
                    if let  data = NSData(contentsOfFile: filePath){
                        dispatch_group_notify(saveDataDispatchGroup, saveDataDispatchQueue) { () -> Void in
                             self.callCompletionBlockWithResponse(data, error: nil)
                        }
                        return
                    }
                }
            }
        }
        operationConnection = NSURLConnection(request: operationRequest!, delegate: self, startImmediately: false)
        var currentQueue = NSOperationQueue.currentQueue()
        var inBackgroundAndInOperationQueue = currentQueue != nil && currentQueue != NSOperationQueue.mainQueue()
        var targetRunLoop = inBackgroundAndInOperationQueue ? NSRunLoop.currentRunLoop() : NSRunLoop.mainRunLoop()
        if operationSavePath != nil{
            operationConnection?.scheduleInRunLoop(targetRunLoop, forMode: NSRunLoopCommonModes)
        }
        else{
            operationConnection?.scheduleInRunLoop(targetRunLoop, forMode: NSDefaultRunLoopMode)
        }
        operationConnection?.start()
        if let requestUrl = operationRequest?.URL?.absoluteString
        {
            NSLog("[%@] %@", operationRequest!.HTTPMethod, requestUrl);
        }
        if cachePolicy == NSURLRequestCachePolicy.ReturnCacheDataDontLoad
        {
            println("Network fail use Cache")
        }
        if inBackgroundAndInOperationQueue{
            operationRunLoop = CFRunLoopGetCurrent()
            CFRunLoopRun()
        }
    }
    //完成
   private func finish(){
        operationConnection?.cancel()
        operationConnection = nil
        decreaseTaskCount()
        if backgroundTaskIdentifier != UIBackgroundTaskInvalid{
            UIApplication.sharedApplication().endBackgroundTask(backgroundTaskIdentifier!)
            backgroundTaskIdentifier = UIBackgroundTaskInvalid
        }
        willChangeValueForKey("isExecuting")
        willChangeValueForKey("isFinished")
        httpClientRequestState = HttpClientRequestState.Finished
        didChangeValueForKey("isExecuting")
        didChangeValueForKey("isFinished")
    }
    //取消
    override func cancel() {
        if !isExecuting{
            return
        }
        super.cancel()
        timeoutTimer = nil
        finish()
    }
   @objc private func requestTimeout(){
        if let failingUrl = operationRequest?.URL{
            var userInfo = [NSLocalizedDescriptionKey:"The operation timed out.",NSURLErrorFailingURLErrorKey:failingUrl,NSURLErrorFailingURLStringErrorKey:failingUrl.absoluteString!]
            var timeoutError:NSError? = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: userInfo)
            connection(nil, error: timeoutError)
        }
    }
    
   func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        expectedContentLength = Float(response.expectedContentLength)
        receivedContentLength = 0
        operationURLResponse = response as? NSHTTPURLResponse
    }
   func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        dispatch_group_async(saveDataDispatchGroup, saveDataDispatchQueue) { () -> Void in
            if self.operationSavePath != nil{
                //try tatch
                if self.operationFileHandle != nil{
                    self.operationFileHandle?.writeData(data) //这要用到错误捕捉，但是swift没有错误捕捉，以后再补上
                }
                //catch error
                else{
                   self.operationConnection?.cancel()
                    var info:Dictionary<String,AnyObject> = [NSFilePathErrorKey:self.operationSavePath!]
                    var writeError = NSError(domain: "HttpClientRequestWriteError", code: 0, userInfo: info)
                    var exception = NSException(name: "write data file", reason: "You provide a invalid path the you can not write data in the path", userInfo: [NSInvalidArgumentException:writeError])
                    exception.raise()
                }
            }
            self.operationData!.appendData(data) //下载的同时也是可以接到到数据的
        }
        if operationProgress != nil{
            //如果返回的数据头不知道大小，就为-1
            if expectedContentLength != -1{
                receivedContentLength = receivedContentLength + Float(data.length)
                operationProgress!(progress: receivedContentLength / expectedContentLength)
            }
            else{
                operationProgress!(progress: -1)
            }
        }
    }

    func connection(connection: NSURLConnection, didSendBodyData bytesWritten: Int, totalBytesWritten: Int, totalBytesExpectedToWrite: Int) {
        if operationProgress != nil && operationRequest!.HTTPMethod == "POST"{
            operationProgress!(progress: Float(totalBytesWritten) / Float(totalBytesExpectedToWrite))
        }
    }
    
    func connectionDidFinishLoading(connection: NSURLConnection) {
        dispatch_group_notify(saveDataDispatchGroup, saveDataDispatchQueue) { () -> Void in
            var response = NSData(data: self.operationData!)
            var error:NSError?
            if  self.operationURLResponse!.MIMEType == "application/json"{
                if self.operationData != nil && self.operationData!.length > 0{
                    var jsonObject: AnyObject? = NSJSONSerialization.JSONObjectWithData(response, options: NSJSONReadingOptions.AllowFragments, error: &error)
                    if jsonObject != nil{
                        response = jsonObject! as! NSData
                    }
                }
            }
            if  self.cacheTime > 0{
                if self.isCacheInValid{
                    if let key = self.operationRequest?.URL?.absoluteString?.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding){
                        HttpClient.sharedCacheKeyDict[key] = NSDate(timeIntervalSinceNow: NSTimeInterval(self.cacheTime))
                        var filePath = self.getCacheFileName()
                        //NSFileManager.defaultManager().crea
                        NSFileManager.defaultManager().createFileAtPath(filePath, contents: response, attributes: nil)
                    }
                }
            }
            self.callCompletionBlockWithResponse(response, error: error)
        }
    }
   func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        callCompletionBlockWithResponse(nil, error: error)
    }
    
  private  func connection(connection:NSURLConnection?,error:NSError?){
        callCompletionBlockWithResponse(nil, error: error)
    }
   private func callCompletionBlockWithResponse(response:AnyObject?,error:NSError?){
        timeoutTimer = nil
        if operationRunLoop != nil{
            CFRunLoopStop(operationRunLoop)
        }
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            var serverError:NSError? = error
            if  serverError != nil && self.operationURLResponse?.statusCode == 500{
            var info = [NSLocalizedDescriptionKey:"Bad Server Response.",NSURLErrorFailingURLErrorKey:self.operationRequest!.URL!,NSURLErrorFailingURLStringErrorKey:self.operationRequest!.URL!.absoluteString!]
                serverError = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo:info)
                
            }
            if  !self.cancelled {
                self.operationCompletion(response: response, urlResponse: self.operationURLResponse, error: serverError)
            }
            self.finish()
        })
    }
    override var asynchronous:Bool{
        get{
            return true
        }
    }
    //增加任务数
  private  func increaseTaskCount(){
        HttpClient.taskCount++
        toggleNetworkActivityIndicator()
    }
  private  func toggleNetworkActivityIndicator(){
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = HttpClient.taskCount > 0
        })
    }
   private func decreaseTaskCount(){
         HttpClient.taskCount--
        toggleNetworkActivityIndicator()
    }
    func synchronized(lock:AnyObject,closure:()->()){
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
  private  func addParametersToRequest(parameters:Dictionary<String,AnyObject>){
        var method = operationRequest!.HTTPMethod
        if method == "POST" || method == "PUT"{
            if queryParameters != nil
            {
                var baseAddress = operationRequest!.URL!.absoluteString!
                if queryParameters!.count > 0{
                    baseAddress = baseAddress + "?\(parameterStringForDictionary(queryParameters!))"
                    operationRequest!.URL = NSURL(string: baseAddress)
                }
            }
            if sendParametersAsJSON!{
                operationRequest?.setValue("application/json", forHTTPHeaderField: "Content-Type")
                var Error:NSError?
                var jsonData = NSJSONSerialization.dataWithJSONObject(parameters, options: NSJSONWritingOptions.allZeros, error: &Error)
                if Error != nil{
                    assert(false, "you use sendParametersAsJSON but the parameter contain invalid data")
                    var exception = NSException(name: "InValidPara", reason: "POST and PUT parameters must be provided as NSDictionary or NSArray when sendParametersAsJSON is set to YES.", userInfo: [NSInvalidArgumentException:"POST and PUT parameters must be provided as NSDictionary or NSArray when sendParametersAsJSON is set to YES."])
                    exception.raise()
                }
                operationRequest?.HTTPBody = jsonData
            }
            else
            {
                var hasData = false
                for (key,value) in parameters{
                    if value is NSData{
                        hasData = true
                    }
                    else if !(value is String) && !(value is NSString) && !(value is NSNumber){
                        assert(false, "\(operationRequest!.HTTPMethod)requests only accept NSString and NSNumber parameters.")
                        var exception = NSException(name: "InValidPara", reason: "\(operationRequest!.HTTPMethod)requests only accept NSString and NSNumber parameters.", userInfo: [NSInvalidArgumentException:"\(operationRequest!.HTTPMethod)requests only accept NSString and NSNumber parameters."])
                        exception.raise()
                    }
                }
                if !hasData{
                    var stringData = (parameterStringForDictionary(parameters) as NSString).UTF8String
                    var postData = NSMutableData(bytes: stringData, length: Int(strlen(stringData)))
                   operationRequest?.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    operationRequest?.HTTPBody = postData
                }
                else{
                    var boundary = "HttpClientRequestBoundary"
                    var contentType = "multipart/form-data; boundary=\(boundary)"
                    operationRequest?.setValue(contentType, forHTTPHeaderField: "Content-Type")
                    var postData = NSMutableData()
                    var dataIdx = 0
                    for (key,value) in parameters{
                        if !(value is NSData){
                            postData.appendData(NSString(format: "--%@\r\n", boundary).dataUsingEncoding(NSUTF8StringEncoding)!)
                            postData.appendData(NSString(format: "Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key).dataUsingEncoding(NSUTF8StringEncoding)!)
                            postData.appendData(NSString(format: "%@", value as! NSObject).dataUsingEncoding(NSUTF8StringEncoding)!) //有可能有问题，要测试
                            postData.appendData(NSString(string: "\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
                        }
                        else{
                             postData.appendData(NSString(format: "--%@\r\n", boundary).dataUsingEncoding(NSUTF8StringEncoding)!)
                            if let imgExtension = value.getImageType(){
                                if useFileName{  // 实际上无法从NSData中获取文件名,所要想要用原始文件名上传,需要把key当作文件名传进来
                                    postData.appendData(NSString(format: "Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x.\(imgExtension)\"\r\n", key,key).dataUsingEncoding(NSUTF8StringEncoding)!)
                                }
                                else{
                                    postData.appendData(NSString(format: "Content-Disposition: attachment; name=\"\(key)\"; filename=\"userfile%d%x.\(imgExtension)\"\r\n",NSDate(timeIntervalSince1970: 0)).dataUsingEncoding(NSUTF8StringEncoding)!)
                                }
                                 postData.appendData(NSString(format: "Content-Type: image/%@\r\n\r\n",imgExtension).dataUsingEncoding(NSUTF8StringEncoding)!)
                            }
                            else{
                                if useFileName{
                                    postData.appendData(NSString(format: "Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x\"\r\n", key,dataIdx, NSDate(timeIntervalSince1970: 0)).dataUsingEncoding(NSUTF8StringEncoding)!)
                                }
                                else{
                                    postData.appendData(NSString(format: "Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x\"\r\n", key,dataIdx,NSDate(timeIntervalSince1970: 0)).dataUsingEncoding(NSUTF8StringEncoding)!)
                                }
                                postData.appendData(NSString(string: "Content-Type: application/octet-stream\r\n\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
                            }
                            postData.appendData(value as! NSData)
                            postData.appendData(NSString(string: "\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
                            dataIdx++
                        }
                    }
                    postData.appendData(NSString(format: "--%@--\r\n", boundary).dataUsingEncoding(NSUTF8StringEncoding)!)
                    operationRequest?.HTTPBody = postData
                }
                
            }
        }
        else {
            var baseAddress = operationRequest!.URL!.absoluteString!
            if operationParameters != nil {
                if operationParameters!.count > 0{
                    baseAddress = baseAddress + "?\(parameterStringForDictionary(operationParameters!))"
                    operationRequest!.URL = NSURL(string: baseAddress)
                }
            }
        }
    }
    
    private func signRequestWithUsername(){
        if Username != nil && Password != nil{
            var authStr = NSString(format: "%@:%@", Username!,Password!)
            var authData = authStr.dataUsingEncoding(NSASCIIStringEncoding)
            var authValue = NSString(format: "Basic %@",authData!.base64EncodedDataWithOptions(NSDataBase64EncodingOptions.EncodingEndLineWithLineFeed))
            operationRequest?.setValue(authValue as String, forHTTPHeaderField: "Authorization")
        }
    }
    
    private func setHeadField(){
        if httpHeaderFields != nil{
            for (key,value) in httpHeaderFields!{
                if let str  = value as? String{
                    operationRequest?.setValue(key, forHTTPHeaderField: str)
                }
            }
        }
    }
    
    private func getCacheFileName()->String{
        var cachePath: AnyObject? = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true).first
        cachePath = (cachePath as! NSString).stringByAppendingPathComponent("HttpClientCaches") as String
        var url = operationRequest!.URL!.absoluteString!.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!
        if !NSFileManager.defaultManager().fileExistsAtPath(cachePath as! String) {
            NSFileManager.defaultManager().createDirectoryAtPath(cachePath as! String , withIntermediateDirectories: true, attributes: nil, error: nil)
        }
        var path = (cachePath as! NSString).stringByAppendingPathComponent(HttpClient.convertUrlToFilename(url))
        return path as String
    }
    
    private static func getCacheFileName(url:String)->String{
        var cachePath: AnyObject? = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true).first
        cachePath = (cachePath as! NSString).stringByAppendingPathComponent("HttpClientCaches") as String
        if !NSFileManager.defaultManager().fileExistsAtPath(cachePath as! String) {
            NSFileManager.defaultManager().createDirectoryAtPath(cachePath as! String , withIntermediateDirectories: true, attributes: nil, error: nil)
        }
        var path = (cachePath as! NSString).stringByAppendingPathComponent(convertUrlToFilename(url))
        return path as String

    }
    
    private static func convertUrlToFilename(url:String)->String{
        var result = (url as NSString).stringByReplacingOccurrencesOfString("\\", withString: "_")
        result = (result as NSString).stringByReplacingOccurrencesOfString("?", withString: "!")
        result = (result as NSString).stringByReplacingOccurrencesOfString("&", withString: "-")
        result = (result as NSString).stringByReplacingOccurrencesOfString(":", withString: "~")
         result = (result as NSString).stringByReplacingOccurrencesOfString("/", withString: "_")
        return result
    }
   private func parameterStringForDictionary(parameters:Dictionary<String,AnyObject>)->String{
        var arrParamters = [String]()
        for (key,value) in parameters{
            if value is String || value is NSString{
                arrParamters.append("\(key)=\((value as! String).encodedURLParameterString())")
            }
            else if value is NSNumber{
                arrParamters.append("\(key)=\(value)")
            }
            else{
                assert(false, "GET and DELETE parameters must be provided as NSDictionary")
                var exception = NSException(name: "InValidPara", reason: "GET and DELETE parameters must be provided as NSDictionary.", userInfo: [NSInvalidArgumentException:"GET and DELETE parameters must be provided as NSDictionary"])
                exception.raise()

            }
        }
        return arrParamters.concat("&")
    }
}

extension String{
    func encodedURLParameterString()->String{
        var result  = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, self as CFStringRef, nil, __CFStringMakeConstantString(":/=,!$&'()*+;[]@#?^%\"`<>{}\\|~ "), CFStringBuiltInEncodings.UTF8.rawValue)
        return result as String
    }

}
extension Array{
    func concat(symble:String)->String{
        var str:String = ""
        if self.count == 0
        {
            return str
        }
        for i in 0..<self.count{
            if self[i] is String{
                if i == self.count - 1{
                    str = str + (self[i] as! String)
                }
                else
                {
                    str = str + (self[i] as! String) + symble
                }
            }
        }
        return str
    }
}

extension NSData{
     func getImageType()->String?{
        if self.length > 4{
            var buffer:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>()
            self.getBytes(&buffer, length: 4)
            println(buffer)
            switch  (buffer.debugDescription){
                case "0x0000000000464947": return "gif"
                case "0x00000000474e5089": return "png"
                case "0x00000000e0ffd8ff": return "jpg"
            default: break
            }
        }
        return nil
    }
}
