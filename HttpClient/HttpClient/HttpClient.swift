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
enum HttpClientRequestState{
    case Ready
    case Executing
    case Finished
}
// 没有继承于NSObject，所以没有dealloc方法用
class HttpClient:NSOperation,NSURLConnectionDataDelegate{
    
    // 用户设定一些Option
    struct HttpClientOption {
        static let TimeOut = "TimeOut"
        static let UserAgent = "UserAgent"
        static let CachePolicy = "CachePolicy" //当使用缓存时设置CachePolicy无效
        static let SendParametersAsJSON  = "SendParametersAsJSON"
        static let BasePath = "BasePath"
        static let UserName = "UserName"
        static let Password = "Password"
        static let UseFileName = "UseFileName"
    }
    
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
    private static var GlobalBasePath:String?
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
            HttpClient.cacheKeyDict = newValue
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
    private var isCacheInValid:Bool = true
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
    private var cachePolicy:NSURLRequestCachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy  //这个可以用一个Option来设定，作为单次请求的参数
    private var basePath:String?  //保存的一个基本路径
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
    static func setGlobelTimeoutInterval(timeInterval:NSTimeInterval){
        HttpClient.GlobalTimeoutInterval = timeInterval
    }
    
    static func setGlobelUserAgent(userAgent:String){
        HttpClient.GlobalUserAgent = userAgent
    }
    
    static func setGlobelCachePolicy(cachePolicy:NSURLRequestCachePolicy){
        HttpClient.GlobalCachePolicy = cachePolicy
    }
    
    static func setGlobalBasePath(basePath:String){
        HttpClient.GlobalBasePath = basePath
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
    }
    
    static func clearCache(){
        HttpClient.sharedCacheKeyDict.removeAll(keepCapacity: false)
    }
    
    static func get(address:String,parameters:Dictionary<String,AnyObject>?,cache:Int,cancelToken:String?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) ->HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Get, parameters: parameters, cache: cache, saveToPath: nil, cancelToken: cancelToken, queryPara:nil, requestOptions:nil,headerFields:nil, progress: nil, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func get(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,saveToPath:String?,cancelToken:String?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) ->HttpClient {
        var httpClient = HttpClient(address: address, method: httpMethod.Get, parameters: parameters, cache: cache, saveToPath: saveToPath, cancelToken: cancelToken, queryPara:nil, requestOptions:requestOptions,headerFields:headerFields, progress: progress, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func Post(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,cancelToken:String?, complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) ->HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Post, parameters: parameters, cache: cache, saveToPath: nil, cancelToken: cancelToken, queryPara:nil, requestOptions:nil,headerFields:nil, progress: nil, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func Post(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,saveToPath:String?,cancelToken:String?,queryPara:Dictionary<String,AnyObject>?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Post, parameters: parameters, cache: cache, saveToPath: saveToPath, cancelToken: cancelToken, queryPara:nil, requestOptions:nil,headerFields:nil, progress: nil, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func Post(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,saveToPath:String?,cancelToken:String?,queryPara:Dictionary<String,AnyObject>?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Post, parameters: parameters, cache: cache, saveToPath: saveToPath, cancelToken: cancelToken, queryPara:queryPara, requestOptions:requestOptions,headerFields:headerFields, progress: progress, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    static func Delete(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,cancelToken:String?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Delete, parameters: parameters, cache: cache, saveToPath: nil, cancelToken: cancelToken, queryPara:nil, requestOptions:nil,headerFields:nil, progress: nil, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }

    static func Put(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,saveToPath:String?,cancelToken:String?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Put, parameters: parameters, cache: cache, saveToPath: saveToPath, cancelToken: cancelToken, queryPara:nil, requestOptions:requestOptions,headerFields:headerFields, progress: progress, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }

    static func Head(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,saveToPath:String?,cancelToken:String?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) -> HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Head, parameters: parameters, cache: cache, saveToPath: saveToPath, cancelToken: cancelToken, queryPara:nil, requestOptions:requestOptions,headerFields:headerFields, progress: progress, complettion: complettion)
        httpClient.requestPath = httpClient.operationRequest?.URL?.absoluteString
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    // MARK: private func
    private init(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,saveToPath:String?,cancelToken:String?,queryPara:Dictionary<String,AnyObject>?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()){
        operationCompletion = complettion
        operationProgress = progress
        operationSavePath = saveToPath
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
             assert(true, "you pass a invalid url")  //非法的Url
            
        }
        if cacheTime > 0{
            cacheTime = cache
        }
        if method != httpMethod.Post && saveToPath == nil{
            operationRequest?.HTTPShouldUsePipelining = true
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
        if requestOptions != nil{
            for (key,value) in requestOptions!{
                if key == HttpClientOption.BasePath{
                    basePath = value as? String
                }
                if key == HttpClientOption.CachePolicy{
                    if let policy = value as? NSURLRequestCachePolicy{
                        cachePolicy = policy
                    }
                }
                if key == HttpClientOption.Password {
                  Password = value as? String
                }
                if key == HttpClientOption.SendParametersAsJSON{
                    sendParametersAsJSON = value as? Bool
                }
                if key == HttpClientOption.TimeOut{
                    if let timeInterval = value as? NSTimeInterval{
                            timeoutInterval = timeInterval
                    }
                }
                if key == HttpClientOption.UserAgent{
                    userAgent = value as? String
                }
                if key == HttpClientOption.UserName{
                    Username = value as? String
                }
                if key == HttpClientOption.UseFileName{
                    if let isUse = value as? Bool{
                        useFileName = isUse
                    }
                }
                
            }
        }
        super.init()
        httpClientRequestState = HttpClientRequestState.Ready
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
        if operationParameters != nil{
            //添加参数
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
           
        }else{
            operationData = NSMutableData()
            timeoutTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutInterval, target: self, selector: "requestTimeout", userInfo: nil, repeats: false)
            operationRequest?.timeoutInterval = timeoutInterval
        }
        //请求之前,检查有没有设置缓存
        if cacheTime > 0{
            if isCacheInvalid(){
                cachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy//如果无效,就不使用缓存
            }
            else{
                cachePolicy = NSURLRequestCachePolicy.ReturnCacheDataElseLoad //有效就使用
            }
        }
        operationRequest?.cachePolicy = cachePolicy
        setHeadField()
        signRequestWithUsername()
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
                }
            }
            else{
                self.operationData!.appendData(data)
            }
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
        if operationProgress != nil && operationRequest!.HTTPMethod == "Post"{
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
            if self.cachePolicy == NSURLRequestCachePolicy.UseProtocolCachePolicy && self.cacheTime > 0{
                if self.isCacheInValid{
                    if let key = self.operationRequest?.URL?.absoluteString{
                        HttpClient.sharedCacheKeyDict[key] = NSDate(timeIntervalSinceNow: NSTimeInterval(self.cacheTime))
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
    //检查缓存是否失效 返回true表示失效
   private func isCacheInvalid()->Bool{
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
                    assert(true, "you use sendParametersAsJSON but the parameter contain invalid data")
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
                        assert(true, "\(operationRequest!.HTTPMethod)requests only accept NSString and NSNumber parameters.")
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
                            postData.appendData(NSString(format: "%@", locale: value as? NSLocale).dataUsingEncoding(NSUTF8StringEncoding)!) //有可能有问题，要测试
                            postData.appendData(NSString(string: "\r\n").dataUsingEncoding(NSUTF8StringEncoding)!)
                        }
                        else{
                             postData.appendData(NSString(format: "--%@\r\n", boundary).dataUsingEncoding(NSUTF8StringEncoding)!)
                            var imgExtension = value.getImageType()
                            if imgExtension != nil{
                                if useFileName{
                                    postData.appendData(NSString(format: "Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x.%@\"\r\n", key,NSDate(timeIntervalSince1970: 0),imgExtension!).dataUsingEncoding(NSUTF8StringEncoding)!)
                                }
                                else{
                                    postData.appendData(NSString(format: "Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x.%@\"\r\n", key,NSDate(timeIntervalSince1970: 0),imgExtension!).dataUsingEncoding(NSUTF8StringEncoding)!)
                                }
                                 postData.appendData(NSString(format: "Content-Type: image/%@\r\n\r\n",imgExtension!).dataUsingEncoding(NSUTF8StringEncoding)!)
                            }
                            else{
                                if useFileName{
                                    postData.appendData(NSString(format: "Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x\"\r\n", key,dataIdx, NSDate(timeIntervalSince1970: 0),imgExtension!).dataUsingEncoding(NSUTF8StringEncoding)!)
                                }
                                else{
                                    postData.appendData(NSString(format: "Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x\"\r\n", key,dataIdx,NSDate(timeIntervalSince1970: 0),imgExtension!).dataUsingEncoding(NSUTF8StringEncoding)!)
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
            if queryParameters!.count > 0{
                baseAddress = baseAddress + "?\(parameterStringForDictionary(queryParameters!))"
                operationRequest!.URL = NSURL(string: baseAddress)
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
                assert(true, "invalid parameter")
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
    func isJPG()->Bool{
        if self.length > 4{
            var buffer:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>()
            self.getBytes(buffer, length: 4)
            return buffer[0] == 0xff && buffer[1] == 0xd8 && buffer[2] == 0xff && buffer[3] == 0xe0;
        }
        return false
    }
    func isPNG()->Bool{
        if self.length > 4{
            var buffer:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>()
            self.getBytes(buffer, length: 4)
            return buffer[0] == 0x89 && buffer[1] == 0x50 && buffer[2] == 0x4e && buffer[3] == 0x47;
        }
        return false
    }
    func isGIF()->Bool{
        if self.length > 3{
            var buffer:UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>()
            self.getBytes(buffer, length: 4)
            return buffer[0] == 0x47 && buffer[1] == 0x49 && buffer[2] == 0x46
        }
        return false
    }
    func getImageType()->String?{
        var type:String?
        if self.isJPG(){
            type = "jpg"
        }
        if self.isGIF(){
            type = "gif"
        }
        if self.isPNG(){
            type = "png"
        }
        return type
    }
}
