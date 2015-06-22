//
//  HttpClient.m
//  QFQThirdLogin
//
//  Created by Tyrant on 2/6/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//


#import "HttpClient.h"
#import <UIKit/UIKit.h>

@interface NSData (Base64)
- (NSString*)base64EncodingWithLineLength:(unsigned int)lineLength;
- (NSString *)getImageType;
- (BOOL)isJPG;
- (BOOL)isPNG;
- (BOOL)isGIF;
@end

@interface NSString (OAURLEncodingAdditions)
- (NSString*)encodedURLParameterString;
@end



enum {
    HttpClientRequestStateReady = 0,
    HttpClientRequestStateExecuting,
    HttpClientRequestStateFinished
};

typedef NSUInteger HttpClientRequestState;
static NSUInteger taskCount = 0;
static NSTimeInterval defaultTimeoutInterval = 20;
static NSString *defaultUserAgent;
@interface HttpClient()
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, strong) NSMutableDictionary *HTTPHeaderFields;
@property (nonatomic, strong) NSMutableURLRequest *operationRequest;
@property (nonatomic, strong) NSMutableData *operationData;
@property (nonatomic, strong) NSFileHandle *operationFileHandle;
@property (nonatomic, strong) NSURLConnection *operationConnection;
@property (nonatomic, strong) NSDictionary *operationParameters;
@property (nonatomic, strong) NSHTTPURLResponse *operationURLResponse;
@property (nonatomic, strong) NSString *operationSavePath;
@property (nonatomic, assign) CFRunLoopRef operationRunLoop;
@property (nonatomic,strong) NSString* requestIdentity;
@property (nonatomic) BOOL cacheIsInValid;
@property (nonatomic) NSInteger cacheTimeOutForSecond;
#if TARGET_OS_IPHONE
@property (nonatomic, readwrite) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
#endif

@property (nonatomic) dispatch_queue_t saveDataDispatchQueue;
@property (nonatomic) dispatch_group_t saveDataDispatchGroup;

@property (nonatomic, copy) HttpClientRequestCompletionHandler operationCompletionBlock;
@property (nonatomic, copy) void (^operationProgressBlock)(float progress);

@property (nonatomic, readwrite) HttpClientRequestState state;
@property (nonatomic, strong) NSString *requestPath;
@property (nonatomic, strong) NSDictionary *queryParameters;
@property (nonatomic, strong) NSTimer *timeoutTimer; // see http://stackoverflow.com/questions/2736967

@property (nonatomic, readwrite) float expectedContentLength;
@property (nonatomic, readwrite) float receivedContentLength;
@property (nonatomic) BOOL useImageName;
- (void)addParametersToRequest:(NSDictionary*)paramsDict;
- (void)finish;

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
- (void)callCompletionBlockWithResponse:(id)response error:(NSError *)error;


@end
@implementation HttpClient
@synthesize cacheIsInValid = _cacheIsInValid;
+ (id)sharedQuene {
    static NSOperationQueue * _sharedQuene = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{ _sharedQuene = [[NSOperationQueue alloc] init]; });
    return _sharedQuene;
}

-(NSOperationQueue*)operationQueue{
    return HttpClient.sharedQuene;
}

@synthesize state = _state;
    - (void)dealloc {
        [_operationConnection cancel];
    #if __IPHONE_OS_VERSION_MIN_REQUIRED < 60000
        dispatch_release(_saveDataDispatchGroup);
        dispatch_release(_saveDataDispatchQueue);
    #endif
    }
    + (void)setDefaultTimeoutInterval:(NSTimeInterval)interval {
        defaultTimeoutInterval = interval;
    }

    + (void)setDefaultUserAgent:(NSString *)userAgent {
        defaultUserAgent = userAgent;
    }

    - (void)increaseTaskCount {
        taskCount++;
        [self toggleNetworkActivityIndicator];
    }

    - (void)decreaseTaskCount {
        taskCount--;
        [self toggleNetworkActivityIndicator];
    }
    - (void)toggleNetworkActivityIndicator {
    #if TARGET_OS_IPHONE
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:(taskCount > 0)];
        });
    #endif
}
+(HttpClient*)GetAsync:(NSString *)address parameters:(NSDictionary *)parameters needCache:(NSInteger)cacheTimeForSecond  completion :(HttpClientRequestCompletionHandler)block{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:GET parameters:parameters needCache:cacheTimeForSecond saveToPath:nil progress:nil completion:block];
        [httpClient.operationQueue addOperation:httpClient];
        return httpClient;
    }
+(HttpClient*)GetAsync:(NSString *)address parameters:(NSDictionary *)parameters needCache:(NSInteger)cacheTimeForSecond  withIdentity:(NSString *)identity completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:GET parameters:parameters needCache:cacheTimeForSecond saveToPath:nil progress:nil completion:block];
    httpClient.requestIdentity = identity;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}
+(HttpClient*)GetAsync:(NSString *)address parameters:(NSDictionary *)parameters needCache:(NSInteger)cacheTimeForSecond withIdentity:(NSString *)identity saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:GET parameters:parameters needCache:cacheTimeForSecond saveToPath:savePath progress:progressBlock completion:block];
    httpClient.requestIdentity = identity;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}
+(HttpClient*)PostAsync:(NSString *)address parameters:(NSDictionary *)parameters  completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:POST parameters:parameters needCache:0 saveToPath:nil progress:nil completion:block];
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}
+(HttpClient*)PostAsync:(NSString *)address parameters:(NSDictionary *)parameters queryParameters:(NSDictionary *)queryParameters completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:POST parameters:parameters needCache:0 saveToPath:nil progress:nil completion:block];
    httpClient.queryParameters = queryParameters;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;

}
+(HttpClient*)PostAsync:(NSString *)address parameters:(NSDictionary *)parameters   withIdentity:(NSString *)identity completion:(HttpClientRequestCompletionHandler)block{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:POST parameters:parameters needCache:0 saveToPath:nil progress:nil completion:block];
    [httpClient.operationQueue addOperation:httpClient];
    httpClient.requestIdentity = identity;
    return httpClient;
}
+(HttpClient*)PostAsync:(NSString *)address parameters:(NSDictionary *)parameters   progress:(void (^)(float))progressBlock withIdentity:(NSString *)identity completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:POST parameters:parameters needCache:0 saveToPath:nil progress:progressBlock completion:block];
    httpClient.requestIdentity = identity;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}

+(HttpClient*)PostAsync:(NSString *)address parameters:(NSDictionary *)parameters queryParameters:(NSDictionary *)queryParameters progress:(void (^)(float))progressBlock withIdentity:(NSString *)identity completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:POST parameters:parameters needCache:0 saveToPath:nil progress:progressBlock completion:block];
    httpClient.requestIdentity = identity;
    httpClient.queryParameters = queryParameters;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}

+(HttpClient*)PostAsync:(NSString *)address parameters:(NSDictionary *)parameters progress:(void (^)(float))progressBlock completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:POST parameters:parameters needCache:0 saveToPath:nil progress:progressBlock completion:block];
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}
+(HttpClient*)PostAsync:(NSString *)address parameters:(NSDictionary *)parameters  saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock withIdentity:(NSString *)identity completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:POST parameters:parameters needCache:0 saveToPath:savePath progress:progressBlock completion:block];
    httpClient.requestIdentity = identity;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}
+(HttpClient*)PutAsync:(NSString *)address parameters:(NSDictionary *)parameters  saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock withIdentity:(NSString *)identity completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:PUT parameters:parameters needCache:0 saveToPath:savePath progress:progressBlock completion:block];
    httpClient.requestIdentity = identity;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}
+(HttpClient*)DeleteAsync:(NSString *)address parameters:(NSDictionary *)parameters  saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock withIdentity:(NSString *)identity completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:DELETE parameters:parameters needCache:0 saveToPath:savePath progress:progressBlock completion:block];
    httpClient.requestIdentity = identity;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}
+(HttpClient*)HeatAsync:(NSString *)address parameters:(NSDictionary *)parameters  saveToPath:(NSString *)savePath progress:(void (^)(float))progressBlock withIdentity:(NSString *)identity completion:(HttpClientRequestCompletionHandler)block
{
    HttpClient* httpClient = [[self alloc] initWithAddress:address method:HEAD parameters:parameters needCache:0 saveToPath:savePath progress:progressBlock completion:block];
    httpClient.requestIdentity = identity;
    [httpClient.operationQueue addOperation:httpClient];
    return httpClient;
}
- (HttpClient*)initWithAddress:(NSString*)urlString method:(RequestMethod)method parameters:(NSDictionary*)parameters needCache:(NSInteger)cacheTimeForSecond  saveToPath:(NSString*)savePath progress:(void (^)(float))progressBlock completion:(HttpClientRequestCompletionHandler)completionBlock  {
    self = [super init];
    self.operationCompletionBlock = completionBlock;
    self.operationProgressBlock = progressBlock;
    self.operationSavePath = savePath;
    self.operationParameters = parameters;
    self.timeoutInterval = defaultTimeoutInterval;
    self.saveDataDispatchGroup = dispatch_group_create();
    self.saveDataDispatchQueue = dispatch_queue_create("HttpClient", DISPATCH_QUEUE_SERIAL);
    self.operationRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
    // pipeline all but POST and downloads
    if (cacheTimeForSecond >0) {
        self.cacheTimeOutForSecond = cacheTimeForSecond;
    }
    if(method != POST && !savePath)
        self.operationRequest.HTTPShouldUsePipelining = YES;
    
    if(method == GET)
        [self.operationRequest setHTTPMethod:@"GET"];
    else if(method == POST)
        [self.operationRequest setHTTPMethod:@"POST"];
    else if(method == PUT)
        [self.operationRequest setHTTPMethod:@"PUT"];
    else if(method == DELETE)
        [self.operationRequest setHTTPMethod:@"DELETE"];
    else if(method == HEAD)
        [self.operationRequest setHTTPMethod:@"HEAD"];
    self.state = HttpClientRequestStateReady;
    return self;
}

- (void)addParametersToRequest:(NSObject*)parameters {
        
        NSString *method = self.operationRequest.HTTPMethod;
        
        if([method isEqualToString:@"POST"] || [method isEqualToString:@"PUT"]) {
            if (self.queryParameters) {
                NSString *baseAddress = self.operationRequest.URL.absoluteString;
                if(self.queryParameters.count > 0)
                    baseAddress = [baseAddress stringByAppendingFormat:@"?%@", [self parameterStringForDictionary:self.queryParameters]];
                [self.operationRequest setURL:[NSURL URLWithString:baseAddress]];
            }
            if(self.sendParametersAsJSON) {
                if([parameters isKindOfClass:[NSArray class]] || [parameters isKindOfClass:[NSDictionary class]]) {
                    [self.operationRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                    NSError *jsonError;
                    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&jsonError];
                    [self.operationRequest setHTTPBody:jsonData];
                }
                else
                    [NSException raise:NSInvalidArgumentException format:@"POST and PUT parameters must be provided as NSDictionary or NSArray when sendParametersAsJSON is set to YES."];
            }
            else if([parameters isKindOfClass:[NSDictionary class]]) {
                __block BOOL hasData = NO;
                NSDictionary *paramsDict = (NSDictionary*)parameters;
                
                [paramsDict.allValues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if([obj isKindOfClass:[NSData class]])
                        hasData = YES;
                    else if(![obj isKindOfClass:[NSString class]] && ![obj isKindOfClass:[NSNumber class]])
                        [NSException raise:NSInvalidArgumentException format:@"%@ requests only accept NSString and NSNumber parameters.", self.operationRequest.HTTPMethod];
                }];
                
                if(!hasData) {
                    const char *stringData = [[self parameterStringForDictionary:paramsDict] UTF8String];
                    NSMutableData *postData = [NSMutableData dataWithBytes:stringData length:strlen(stringData)];
                    [self.operationRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"]; //added by uzys
                    [self.operationRequest setHTTPBody:postData];
                }
                else {
                    NSString *boundary = @"SVHTTPRequestBoundary";
                    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
                    [self.operationRequest setValue:contentType forHTTPHeaderField: @"Content-Type"];
                    
                    __block NSMutableData *postData = [NSMutableData data];
                    __block int dataIdx = 0;
                    // add string parameters
                    [paramsDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                        if(![obj isKindOfClass:[NSData class]]) {
                            [postData appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                            [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
                            [postData appendData:[[NSString stringWithFormat:@"%@", obj] dataUsingEncoding:NSUTF8StringEncoding]];
                            [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                        } else {
                            [postData appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                            
                            NSString *imageExtension = [obj getImageType];
                            if(imageExtension != nil) {
                                    [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x.%@\"\r\n", key,dataIdx,(int)[[NSDate date] timeIntervalSince1970],imageExtension] dataUsingEncoding:NSUTF8StringEncoding]];
  
                                [postData appendData:[[NSString stringWithFormat:@"Content-Type: image/%@\r\n\r\n",imageExtension] dataUsingEncoding:NSUTF8StringEncoding]];
                            }
                            else {
                                [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: attachment; name=\"%@\"; filename=\"userfile%d%x\"\r\n", key,dataIdx,(int)[[NSDate date] timeIntervalSince1970]] dataUsingEncoding:NSUTF8StringEncoding]];
                                [postData appendData:[@"Content-Type: application/octet-stream\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                            }
                            
                            [postData appendData:obj];
                            [postData appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
                            dataIdx++;
                        }
                    }];
                    
                    [postData appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
                    [self.operationRequest setHTTPBody:postData];
                }
            }
            else
                [NSException raise:NSInvalidArgumentException format:@"POST and PUT parameters must be provided as NSDictionary when sendParametersAsJSON is set to NO."];
        }
        else if([parameters isKindOfClass:[NSDictionary class]]) {
            NSDictionary *paramsDict = (NSDictionary*)parameters;
            NSString *baseAddress = self.operationRequest.URL.absoluteString;
            if(paramsDict.count > 0)
                baseAddress = [baseAddress stringByAppendingFormat:@"?%@", [self parameterStringForDictionary:paramsDict]];
            [self.operationRequest setURL:[NSURL URLWithString:baseAddress]];
        }
        else
            [NSException raise:NSInvalidArgumentException format:@"GET and DELETE parameters must be provided as NSDictionary."];
    }
- (NSString*)parameterStringForDictionary:(NSDictionary*)parameters {
        NSMutableArray *stringParameters = [NSMutableArray arrayWithCapacity:parameters.count];
        
        [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if([obj isKindOfClass:[NSString class]]) {
                [stringParameters addObject:[NSString stringWithFormat:@"%@=%@", key, [obj encodedURLParameterString]]];
            }
            else if([obj isKindOfClass:[NSNumber class]]) {
                [stringParameters addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
            }
            else
                [NSException raise:NSInvalidArgumentException format:@"%@ requests only accept NSString, NSNumber and NSData parameters.", self.operationRequest.HTTPMethod];
        }];
        
        return [stringParameters componentsJoinedByString:@"&"];
    }
- (void)signRequestWithUsername:(NSString*)username password:(NSString*)password  {
    NSString *authStr = [NSString stringWithFormat:@"%@:%@", username, password];
    NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
    NSString *authValue = [NSString stringWithFormat:@"Basic %@", [authData base64EncodingWithLineLength:140]];
    [self.operationRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
}
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    [self.operationRequest setValue:value forHTTPHeaderField:field];
}
- (void)setTimeoutTimer:(NSTimer *)newTimer {
    
    if(_timeoutTimer)
        [_timeoutTimer invalidate], _timeoutTimer = nil;
    
    if(newTimer)
        _timeoutTimer = newTimer;
}
- (void)start {
    
    if(self.isCancelled) {
        [self finish];
        return;
    }
#if TARGET_OS_IPHONE
    // all requests should complete and run completion block unless we explicitely cancel them.
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        if(self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }];
#endif
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self increaseTaskCount];
    });
    
    if(self.operationParameters)
        [self addParametersToRequest:self.operationParameters];
    if(self.userAgent)
        [self.operationRequest setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    else if(defaultUserAgent)
        [self.operationRequest setValue:defaultUserAgent forHTTPHeaderField:@"User-Agent"];
    
    [self willChangeValueForKey:@"isExecuting"];
    self.state = HttpClientRequestStateExecuting;
    [self didChangeValueForKey:@"isExecuting"];
    
    if(self.operationSavePath) {
        [[NSFileManager defaultManager] createFileAtPath:self.operationSavePath contents:nil attributes:nil];
        self.operationFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.operationSavePath];
    } else {
        self.operationData = [[NSMutableData alloc] init];
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeoutInterval target:self selector:@selector(requestTimeout) userInfo:nil repeats:NO];
        [self.operationRequest setTimeoutInterval:self.timeoutInterval];
    }
    //请求之前,检查有没有设置缓存
    if (self.cacheTimeOutForSecond>0) {
        //如果有设置缓存,检查是否有效果
        if(self.cacheIsInValid) self.cachePolicy = NSURLRequestUseProtocolCachePolicy; //如果无效,就不使用缓存
        else self.cachePolicy = NSURLRequestReturnCacheDataElseLoad; //有效就使用
    }
//    #ifdef DEBUG
//    #else
//    if([Tool  currentNetWorkState] == CONNECTIONLESS){  //如果没有网络,就使用缓存数据
//        self.cachePolicy = NSURLRequestReturnCacheDataDontLoad;
//    }
//    #endif
    [self.operationRequest setCachePolicy:self.cachePolicy];
    
    self.operationConnection = [[NSURLConnection alloc] initWithRequest:self.operationRequest delegate:self startImmediately:NO];

    NSOperationQueue *currentQueue = [NSOperationQueue currentQueue];
    BOOL inBackgroundAndInOperationQueue = (currentQueue != nil && currentQueue != [NSOperationQueue mainQueue]);
    NSRunLoop *targetRunLoop = (inBackgroundAndInOperationQueue) ? [NSRunLoop currentRunLoop] : [NSRunLoop mainRunLoop];
    
    if(self.operationSavePath) // schedule on main run loop so scrolling doesn't prevent UI updates of the progress block
        [self.operationConnection scheduleInRunLoop:targetRunLoop forMode:NSRunLoopCommonModes];
    else
        [self.operationConnection scheduleInRunLoop:targetRunLoop forMode:NSDefaultRunLoopMode];
    
    [self.operationConnection start];
    
    NSLog(@"[%@] %@", self.operationRequest.HTTPMethod, self.operationRequest.URL.absoluteString);
    if (self.cachePolicy == NSURLRequestReturnCacheDataDontLoad) {
        NSLog(@"Network fail use Cache");
    }
    // make NSRunLoop stick around until operation is finished
    if(inBackgroundAndInOperationQueue) {
        self.operationRunLoop = CFRunLoopGetCurrent();
        CFRunLoopRun();
    }
}
// private method; not part of NSOperation
- (void)finish {
    [self.operationConnection cancel];
    self.operationConnection = nil;
    
    [self decreaseTaskCount];
    
#if TARGET_OS_IPHONE
    if(self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
#endif
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.state = HttpClientRequestStateFinished;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}
- (void)cancel {
    if(![self isExecuting])
        return;
    
    [super cancel];
    self.timeoutTimer = nil;
    [self finish];
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isFinished {
    return self.state == HttpClientRequestStateFinished;
}

- (BOOL)isExecuting {
    return self.state == HttpClientRequestStateExecuting;
}

- (HttpClientRequestState)state {
    @synchronized(self) {
        return _state;
    }
}

- (void)setState:(HttpClientRequestState)newState {
    @synchronized(self) {
        [self willChangeValueForKey:@"state"];
        _state = newState;
        [self didChangeValueForKey:@"state"];
    }
}

#pragma mark -
#pragma mark Delegate Methods

- (void)requestTimeout {
    
    NSURL *failingURL = self.operationRequest.URL;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"The operation timed out.", NSLocalizedDescriptionKey,
                              failingURL, NSURLErrorFailingURLErrorKey,
                              failingURL.absoluteString, NSURLErrorFailingURLStringErrorKey, nil];
    
    NSError *timeoutError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:userInfo];
    [self connection:nil didFailWithError:timeoutError];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.expectedContentLength = response.expectedContentLength;
    self.receivedContentLength = 0;
    self.operationURLResponse = (NSHTTPURLResponse*)response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    dispatch_group_async(self.saveDataDispatchGroup, self.saveDataDispatchQueue, ^{
        if(self.operationSavePath) {
            @try { //writeData: can throw exception when there's no disk space. Give an error, don't crash
                [self.operationFileHandle writeData:data];
            }
            @catch (NSException *exception) {
                [self.operationConnection cancel];
                NSError *writeError = [NSError errorWithDomain:@"SVHTTPRequestWriteError" code:0 userInfo:exception.userInfo];
                [self callCompletionBlockWithResponse:nil error:writeError];
            }
        }
        else
            [self.operationData appendData:data];
    });
    
    if(self.operationProgressBlock) {
        //If its -1 that means the header does not have the content size value
        if(self.expectedContentLength != -1) {
            self.receivedContentLength += data.length;
            self.operationProgressBlock(self.receivedContentLength/self.expectedContentLength);
        } else {
            //we dont know the full size so always return -1 as the progress
            self.operationProgressBlock(-1);
        }
    }
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    if(self.operationProgressBlock && [self.operationRequest.HTTPMethod isEqualToString:@"POST"]) {
        self.operationProgressBlock((float)totalBytesWritten/(float)totalBytesExpectedToWrite);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    dispatch_group_notify(self.saveDataDispatchGroup, self.saveDataDispatchQueue, ^{
        
        id response = [NSData dataWithData:self.operationData];
        NSError *error = nil;
        
        if ([[self.operationURLResponse MIMEType] isEqualToString:@"application/json"]) {
            if(self.operationData && self.operationData.length > 0) {
                NSDictionary *jsonObject = [NSJSONSerialization JSONObjectWithData:response options:NSJSONReadingAllowFragments error:&error];
                
                if(jsonObject)
                    response = jsonObject;
            }
        }
        if (self.cachePolicy == NSURLRequestUseProtocolCachePolicy&&self.cacheTimeOutForSecond >0) {
            if (self.cacheIsInValid) {
                     [[HttpClient sharedCacheKeyDict] setObject:[[NSDate alloc] initWithTimeIntervalSinceNow:self.cacheTimeOutForSecond] forKey:[[self.operationRequest.URL absoluteString]  stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
        }
        [self callCompletionBlockWithResponse:response error:error];
    });
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self callCompletionBlockWithResponse:nil error:error];
}

- (void)callCompletionBlockWithResponse:(id)response error:(NSError *)error {
    self.timeoutTimer = nil;
    
    if(self.operationRunLoop)
        CFRunLoopStop(self.operationRunLoop);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *serverError = error;
        
        if(!serverError && self.operationURLResponse.statusCode == 500) {
            serverError = [NSError errorWithDomain:NSURLErrorDomain
                                              code:NSURLErrorBadServerResponse
                                          userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                    @"Bad Server Response.", NSLocalizedDescriptionKey,
                                                    self.operationRequest.URL, NSURLErrorFailingURLErrorKey,
                                                    self.operationRequest.URL.absoluteString, NSURLErrorFailingURLStringErrorKey, nil]];
        }
        
        if(self.operationCompletionBlock && !self.isCancelled)
            self.operationCompletionBlock(response, self.operationURLResponse, serverError);
        [self finish];
    });
}



+(void)cancelAllRequests{
    [[HttpClient sharedQuene] cancelAllOperations];
}

+(void)cancelRequestsWithPath:(NSString *)path
{
    [((NSOperationQueue*)[HttpClient sharedQuene]).operations enumerateObjectsUsingBlock:^(id request, NSUInteger idx, BOOL *stop) {
        NSString *requestPath = [request valueForKey:@"requestPath"];
        if([requestPath isEqualToString:path])
            [request cancel];
    }];
}
+(void)cancelRequestWithIndentity:(NSString *)identity
{
    [((NSOperationQueue*)[HttpClient sharedQuene]).operations enumerateObjectsUsingBlock:^(id request, NSUInteger idx, BOOL *stop) {
        NSString *requestIdentity =  ((HttpClient*)request).requestIdentity;
        if([requestIdentity isEqualToString:identity])
            [request cancel];
           NSLog(@"取消请求%@",identity);
    }];
}
-(BOOL)cacheIsInValid
{
    NSDate*  expireDate =[[HttpClient sharedCacheKeyDict] objectForKey:[[self.operationRequest.URL absoluteString] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    if(expireDate == nil )
        return YES;
    if ([[NSDate date] compare:expireDate] == NSOrderedDescending ) {
        NSLog(@"缓存已经失效");
        return YES;
    }
    return NO;
}
+(void)clearUrlCache:(NSString *)url
{
    [[HttpClient sharedCacheKeyDict] removeObjectForKey:url];
}
+(void)clearCache
{
    [[HttpClient sharedCacheKeyDict] removeAllObjects];
}
+(NSMutableDictionary*)sharedCacheKeyDict{
    static NSMutableDictionary* sharedSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedSingleton = [NSMutableDictionary new]; });
    return sharedSingleton;
}


@end


@implementation NSString (HttpClient)

- (NSString*)encodedURLParameterString {
    NSString *result = (__bridge_transfer NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                            (__bridge CFStringRef)self,
                                                                                            NULL,
                                                                                            CFSTR(":/=,!$&'()*+;[]@#?^%\"`<>{}\\|~ "),
                                                                                            kCFStringEncodingUTF8);
    return result;
}

@end
static char encodingTable[64] = {
    'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
    'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
    'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
    'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/' };

@implementation NSData (HttpClient)

- (NSString *)base64EncodingWithLineLength:(unsigned int) lineLength {
    const unsigned char	*bytes = [self bytes];
    NSMutableString *result = [NSMutableString stringWithCapacity:[self length]];
    unsigned long ixtext = 0;
    unsigned long lentext = [self length];
    long ctremaining = 0;
    unsigned char inbuf[3], outbuf[4];
    short i = 0;
    unsigned int charsonline = 0;
    short ctcopy = 0;
    unsigned long ix = 0;
    
    while( YES ) {
        ctremaining = lentext - ixtext;
        if( ctremaining <= 0 ) break;
        
        for( i = 0; i < 3; i++ ) {
            ix = ixtext + i;
            if( ix < lentext ) inbuf[i] = bytes[ix];
            else inbuf [i] = 0;
        }
        
        outbuf [0] = (inbuf [0] & 0xFC) >> 2;
        outbuf [1] = ((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4);
        outbuf [2] = ((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6);
        outbuf [3] = inbuf [2] & 0x3F;
        ctcopy = 4;
        
        switch( ctremaining ) {
            case 1:
                ctcopy = 2;
                break;
            case 2:
                ctcopy = 3;
                break;
        }
        
        for( i = 0; i < ctcopy; i++ )
            [result appendFormat:@"%c", encodingTable[outbuf[i]]];
        
        for( i = ctcopy; i < 4; i++ )
            [result appendFormat:@"%c",'='];
        
        ixtext += 3;
        charsonline += 4;
    }
    
    return result;
}

- (BOOL)isJPG {
    if (self.length > 4) {
        unsigned char buffer[4];
        [self getBytes:&buffer length:4];
        
        return buffer[0]==0xff &&
        buffer[1]==0xd8 &&
        buffer[2]==0xff &&
        buffer[3]==0xe0;
    }
    
    return NO;
}

- (BOOL)isPNG {
    if (self.length > 4) {
        unsigned char buffer[4];
        [self getBytes:&buffer length:4];
        
        return buffer[0]==0x89 &&
        buffer[1]==0x50 &&
        buffer[2]==0x4e &&
        buffer[3]==0x47;
    }
    
    return NO;
}

- (BOOL)isGIF {
    if(self.length >3) {
        unsigned char buffer[4];
        [self getBytes:&buffer length:4];
        
        return buffer[0]==0x47 &&
        buffer[1]==0x49 &&
        buffer[2]==0x46; //Signature ASCII 'G','I','F'
    }
    return  NO;
}

- (NSString *)getImageType {
    NSString *ret;
    if([self isJPG]) {
        ret=@"jpg";
    }
    else if([self isGIF]) {
        ret=@"gif";
    }
    else if([self isPNG]) {
        ret=@"png";
    }
    else {
        ret=nil;
    }
    return ret;
}
@end
