# HttpClient
=====
HttpClient is a easy-to-use, high efficiency and simplify Http tool.I reference SVHTTPRequest and change some features.If these code 
infringement the SVHTTPRequest, please let me know. Thanks.
 Version: 1.0.0   copy right: Gforce,
### Setp1: configration the http environment， 
            There are some default global configs, which are GlobalCachePolicy(default value is                         NSURLRequestCachePolicy.UseProtocolCachePolicy ),GlobalNeedSendParametersAsJSON(the default value is false), GlobalTimeoutInterval(the default value is 20), GlobalUserAgent(the default value is HttpClient)           
And there are come static funtcion to configration to global configs.which are 
``` Swift
            HttpClient.setGlobalCachePolicy(NSURLRequestCachePolicy.UseProtocolCachePolicy)
            HttpClient.setGlobalNeedSendParametersAsJSON(false)
            HttpClient.setGlobalUsername("httpclient") 
            HttpClient.setGlobalPassword("123456")
            HttpClient.setGlobalTimeoutInterval(40)
            HttpClient.setGlobalUserAgent("Firefox")
