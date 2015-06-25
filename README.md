# HttpClient
HttpClient is a easy-to-use, high efficiency and simplify Http tool.I reference SVHTTPRequest and change some features.If these code 
infringement the SVHTTPRequest, please let me know. Thanks.
Version: 1.0.0   copy right: Gforce,

* before use, you may want to config the http environment， there are some global function you can use which are:

      HttpClient.setGlobalCachePolicy(NSURLRequestCachePolicy.UseProtocolCachePolicy)  
        // cache policy, the default value is NSURLRequestCachePolicy.UseProtocolCachePolicy
      HttpClient.setGlobalNeedSendParametersAsJSON(false) 
        // send post value as json the default value is false
      HttpClient.setGlobalUsername("httpclient") 
        //set request authentication username，default is nil (i have't test this feature)
      HttpClient.setGlobalPassword("123456") 
        //set request authentication password，default is nil (i have't test this feature)
      HttpClient.setGlobalTimeoutInterval(40) 
        // set request time out ,the default value is 20
      HttpClient.setGlobalUserAgent("Firefox") 
        // set User Agent the default if HttpClient
* after set these global features you can use if very simple
*  HttpClient.get("http://www.163.com", parameters: nil, cache: 20, cancelToken: nil, complettion: { (response, urlResponse, error) -> () in
                if error != nil{
                    println("there is a error\(error)")
                    return
                }
                if let data = response as? NSData{
                    if let result = NSString(data: data, encoding: NSUTF8StringEncoding){
                      println(result)
                    }
                }
            })
