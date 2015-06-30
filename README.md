# HttpClient
=====
HttpClient is a easy-to-use, high efficiency and simplify Http tool.I reference SVHTTPRequest and change some features.If these code 
infringement the SVHTTPRequest, please let me know. Thanks.
 Version: 1.0.0   copy right: Gforce,
### Setp1: configration the http environment， 
            There are some default global configs, which are:
            GlobalCachePolicy(default value is
            NSURLRequestCachePolicy.UseProtocolCachePolicy ),
            GlobalNeedSendParametersAsJSON(the default value is false),
            GlobalTimeoutInterval(the default value is 20), 
            GlobalUserAgent(the default value is HttpClient)           
And there are come static funtcions to configration to global configs.which are 
``` Swift
            HttpClient.setGlobalCachePolicy(NSURLRequestCachePolicy.UseProtocolCachePolicy)
            HttpClient.setGlobalNeedSendParametersAsJSON(false)
            HttpClient.setGlobalUsername("httpclient") 
            HttpClient.setGlobalPassword("123456")
            HttpClient.setGlobalTimeoutInterval(40)
            HttpClient.setGlobalUserAgent("Firefox")
 ```
 
 ### Setp2: Use HttpClient
 #### No1, you need know some parameters in the httpclient request option. let's see the main init function
 ``` Swift
private init(address:String,method:httpMethod,parameters:Dictionary<String,AnyObject>?, cache:Int,cancelToken:String?,queryPara:Dictionary<String,AnyObject>?, requestOptions:Dictionary<String,AnyObject>?,headerFields:Dictionary<String,AnyObject>?, progress:((progress:Float)->())?,complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->()){
```
    let's see these parameters. please note, this is a private struction function, so you can't init it. use static function Get or Post to request. I use init() is to let you know all the parameters
    `address:String`:  the request address,
    `method:httpMethod`: there is a enum,
    `parameters:Dictionary<String,AnyObject>?`: this is the request parameters, when you use get method.the parameters will be added to the url, and when tou use the pose method. all the parameters will be wraped in the http post content.
    `cache:Int` if you need cache this url, you can set the cache time bigger than 0. it any work at Get method, in post method this feature can not work
    `cancelToken:String?`: this is the cancel token, if you want cancel this request, just call the static funtion HttpClient.cancelRequestWithIndentity(token:string)
    `queryPara:Dictionary<String,AnyObject>?`: this parameter is special.  you can use it on this condition. when you use post method but also want to add some parameters to the url, then use this parameter
    `requestOptions:Dictionary<String,AnyObject>?`: this parameter let you personalization this request.make it not obey the global config. for instance, if you need set this request timeout . you need add timeout in the dictionary. and pass it to the request.
    `headerFields:Dictionary<String,AnyObject>?`,: the paramter is to set the request header.
    `progress:((progress:Float)->())?`: this is the upload&download progress
    `complettion:(response:AnyObject?,urlResponse:NSHTTPURLResponse?,error:NSError?)->())`: this is the completion handler response is a nsdata object, if error occur, the response eill be nil and you can fetch the error info from error
