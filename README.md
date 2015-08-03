# HttpClient
=====
HttpClient is a easy-to-use, high efficiency and simplify Http tool.I reference SVHTTPRequest and change some features.If these code infringement the SVHTTPRequest, please let me know. Thanks.
######Version: 1.0.0 ,       copy right: Gforce
##Usage
###Setp1: configration the http environment
  use the HttpClient static function to configration the http environment
  ```swift
  HttpClient.setGlobalCachePolicy(NSURLRequestCachePolicy.UseProtocolCachePolicy)
  HttpClient.setGlobalNeedSendParametersAsJSON(false)
  HttpClient.setGlobalUsername("yourUserName") 
  HttpClient.setGlobalPassword("123456")
  HttpClient.setGlobalTimeoutInterval(40)
  HttpClient.setGlobalUserAgent("Firefox")
  ```
  if you do not configration the http environment, the HttpClient will use the default config which are:
  ```swift
  GlobalCachePolicy//(default value is NSURLRequestCachePolicy.UseProtocolCachePolicy ),
  GlobalNeedSendParametersAsJSON//(the default value is false),
  GlobalTimeoutInterval//(the default value is 20), 
  GlobalUserAgent//(the default value is HttpClient)  
  ```
###Setp2 Use HttpClient static function
  call the HttpClient static function once is to creat a HttpClient instance, the initialize function is
  ```swift
  private init(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,cancelToken:String?,queryPara:Dictionary<String,AnyObject>?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()){}
  ```
  you will note this is a private construction. and so you can not call it directly. let's see the parameters
  ```swift
  address:String// the request address,
  method:httpMethod//there is a enum, specifically request method
  parameters:Dictionary<String,AnyObject>?// this is the request parameters, when you use get method.the parameters will be added to the url, and when tou use the pose method. all the parameters will be wraped in the http post content.
  cache:Int//if you need cache this url, you can set the cache time bigger than 0. it any work at Get method, in post method this feature can not work
  cancelToken:String?//this is the cancel token, if you want cancel this request, just call the static funtion HttpClient.cancelRequestWithIndentity(token:string)
  queryPara:Dictionary<String,AnyObject>?// this parameter is special.  you can use it on this condition. when you use post method but also want to add some parameters to the url, then use this parameter
  requestOptions:Dictionary<String,AnyObject>?// this parameter let you personalization this request.make it not obey the global config. for instance, if you need set this request timeout . you need add timeout in the dictionary. and pass it to the request.
  headerFields:Dictionary<String,AnyObject>?// the paramter is to set the request header.
  progress:((progress:Float)->())?// this is the upload&download progress
  complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->())// this is the completion handler response is a nsdata object, if error occur, the response eill be nil and you can fetch the error info from error
  ```
###Step3 Handle the callback block
  the last thing is to handle the callback block,it's very simple.
  First: check the error filed, if error exist, handle the error and display the correct message to the user
  Second: convert the response to the NSData, accord the request result, it can be a Image NSData , Text NSData or JSON.
  Third:convert the NSData to the Model or Object and use it
###Setp4 Other operation 
  Cache the request: pass the number than bigger 0(this is  second unit) to the Cache parameter. and make sure is Get method, the HttpClient will cache this request automatically and store the cache as NSData to the APP's Cache fold.
    
    
  Cancel the request: it's very simple. when you want to cancel a request, you must set the cancelToken parameter. can you'd better make the cancelToken is unique. then call the static funtion cancelRequestWithIndentity, pass the cancelToken to this funtion and the HttpClient will cancel this request. as a consequence the result block will not run.meanwhile, if you do not set the cancelToken, you can use the url to cancel the request, call the static funtion cancelRequestsWithPath and pass the url. if you want cancel all the request, call the static funtion cancelAllRequests the HttpClient will terminate all the request that is processing.
    
    
  Clear the cache: compare the cancel request, you can clear the cache manually, call the static funtion clearUrlCache(url:String) and pass the url that you have set cache, you can call the static funtion clearCache() as well, it can clear all the cache file that the HttpClient created.
    
    
  Set username and password. some website need certificate,it need user provide the username and password.you can use the global static funtion set the global username and password or store the username and password in a dictionary then pass to a specifically request
    
    
#####After read all the ReadMe and you can use it simply and pleasant.  you can also discovery some new features in the code. Thank you
  
