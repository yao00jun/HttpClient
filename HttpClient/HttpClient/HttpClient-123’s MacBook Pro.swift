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
        static let CachePolicy = "CachePolicy"
        static let SendParametersAsJSON  = "SendParametersAsJSON"
        static let BasePath = "BasePath"
        static let UserName = "UserName"
        static let Password = "Password"
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
    private var timeoutTimer:NSTimer?
    private var expectedContentLength:Float = 0
    private var receivedContentLength:Float = 0
    private var configDict:Dictionary<String,AnyObject>?
    private var userAgent:String?   //这个可用一个option来设定 作为单次请求的参数
    private var timeoutInterval:NSTimeInterval //这个可以用一个Option来设定，作为单次请求的参数
    private var cachePolicy:NSURLRequestCachePolicy = NSURLRequestCachePolicy.UseProtocolCachePolicy  //这个可以用一个Option来设定，作为单次请求的参数
    private var basePath:String?  //保存的一个基本路径
    private var sendParametersAsJSON:Bool?
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
    
    static func get(address:String,parameters:Dictionary<String,AnyObject>?,cache:Int,cancelToken:String?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()) ->HttpClient{
        var httpClient = HttpClient(address: address, method: httpMethod.Get, parameters: parameters, cache: cache, saveToPath: nil, cancelToken: cancelToken, queryParameters:nil, requestOptions:nil, progress: nil, complettion: complettion)
        self.operationQueue.addOperation(httpClient)
        return httpClient
    }
    
    init(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,saveToPath:String?,cancelToken:String?,queryParameters:Dictionary<String,AnyObject>?, requestOptions:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()){
        operationCompletion = complettion
        operationProgress = progress
        operationSavePath = saveToPath
        operationParameters = parameters
        timeoutInterval = HttpClient.GlobalTimeoutInterval
        sendParametersAsJSON = HttpClient.GlobalNeedSendParametersAsJSON
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
    func finish(){
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
    func requestTimeout(){
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
    }
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        callCompletionBlockWithResponse(nil, error: error)
    }
    
    func connection(connection:NSURLConnection?,error:NSError?){
        callCompletionBlockWithResponse(nil, error: error)
    }
    func callCompletionBlockWithResponse(response:AnyObject?,error:NSError?){
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
    func increaseTaskCount(){
        HttpClient.taskCount++
        toggleNetworkActivityIndicator()
    }
    func toggleNetworkActivityIndicator(){
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = HttpClient.taskCount > 0
        })
    }
    func decreaseTaskCount(){
         HttpClient.taskCount--
        toggleNetworkActivityIndicator()
    }
    //检查缓存是否失效 返回true表示失效
    func isCacheInvalid()->Bool{
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
    
    func addParametersToRequest(parameters:Dictionary<String,AnyObject>){
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
                    var postData = NSMutableData(bytes: stringData, length: strlen(stringData))
                   // NSMutableData(bytes: <#UnsafePointer<Void>#>, length: <#Int#>)
                }
            }
        }
    }
    
    func parameterStringForDictionary(parameters:Dictionary<String,AnyObject>)->String{
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