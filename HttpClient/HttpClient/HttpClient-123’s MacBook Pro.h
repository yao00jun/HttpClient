//
//  HttpClient.h
//  QFQThirdLogin
//
//  Created by Tyrant on 2/6/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

#import <Foundation/Foundation.h>
enum {
    GET = 0,
    POST,
    PUT,
    DELETE,
    HEAD
};
typedef NSUInteger RequestMethod;
typedef void (^HttpClientRequestCompletionHandler)(id response, NSHTTPURLResponse *urlResponse, NSError *error);
@interface HttpClient : NSOperation


/**
 *  常用HTTP请求(GET)
 *
 *  @param address            HTTP地址
 *  @param parameters         参数
 *  @param cacheTimeForSecond 缓存时间（一般设置为 0）
 *  @param identity           请求标示符
 *  @param block              回调函数
 *
 *  @return
 */
+(HttpClient*)GetAsync:(NSString*)address parameters:(NSDictionary*)parameters needCache:(NSInteger)cacheTimeForSecond withIdentity:(NSString*)identity completion:(HttpClientRequestCompletionHandler)block;

/**
 *  常用HTTP请求(POST)
 *
 *  @param address    HTTP地址
 *  @param parameters 参数
 *  @param identity   请求标示符
 *  @param block      回调函数
 *
 *  @return
 */
+(HttpClient*)PostAsync:(NSString*)address parameters:(NSDictionary*)parameters withIdentity:(NSString*)identity completion:(HttpClientRequestCompletionHandler)block;




+(HttpClient*)GetAsync:(NSString*)address parameters:(NSDictionary*)parameters needCache:(NSInteger)cacheTimeForSecond completion:(HttpClientRequestCompletionHandler)block;





+(HttpClient*)GetAsync:(NSString*)address parameters:(NSDictionary*)parameters needCache:(NSInteger)cacheTimeForSecond withIdentity:(NSString*)identity saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock completion:(HttpClientRequestCompletionHandler)block;




+(HttpClient*)PostAsync:(NSString*)address parameters:(NSDictionary*)parameters completion:(HttpClientRequestCompletionHandler)block;


+(HttpClient*)PostAsync:(NSString *)address parameters:(NSDictionary *)parameters queryParameters:(NSDictionary*)queryParameters completion:(HttpClientRequestCompletionHandler)block;


+(HttpClient*)PostAsync:(NSString*)address parameters:(NSDictionary*)parameters progress:(void (^)(float progress))progressBlock completion:(HttpClientRequestCompletionHandler)block;




+(HttpClient*)PostAsync:(NSString*)address parameters:(NSDictionary*)parameters  progress:(void (^)(float progress))progressBlock withIdentity:(NSString*)identity completion:(HttpClientRequestCompletionHandler)block;

+(HttpClient*)PostAsync:(NSString*)address parameters:(NSDictionary*)parameters  queryParameters:(NSDictionary*)queryParameters progress:(void (^)(float progress))progressBlock withIdentity:(NSString*)identity completion:(HttpClientRequestCompletionHandler)block;


+(HttpClient*)PostAsync:(NSString*)address parameters:(NSDictionary*)parameters  saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock withIdentity:(NSString*)identity completion:(HttpClientRequestCompletionHandler)block;




+(HttpClient*)PutAsync:(NSString*)address parameters:(NSDictionary*)parameters  saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock withIdentity:(NSString*)identity completion:(HttpClientRequestCompletionHandler)block;




+(HttpClient*)DeleteAsync:(NSString*)address parameters:(NSDictionary*)parameters  saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock withIdentity:(NSString*)identity completion:(HttpClientRequestCompletionHandler)block;




+(HttpClient*)HeatAsync:(NSString*)address parameters:(NSDictionary*)parameters saveToPath:(NSString*)savePath progress:(void (^)(float progress))progressBlock withIdentity:(NSString*)identity completion:(HttpClientRequestCompletionHandler)block;




+ (void)cancelRequestsWithPath:(NSString*)path;


/**
 *  取消所有网络请求
 */
+(void)cancelAllRequests;


/**
 *  取消单个网络请求
 *
 *  @param identity 请求标示符
 */
+(void)cancelRequestWithIndentity:(NSString*)identity;

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;

/**
 *  清除指定URL缓存
 *
 *  @param url URL
 */
+(void)clearUrlCache:(NSString*)url;

/**
 *  清除所有HTTP缓存
 */
+(void)clearCache;


/**
 *  设置缓存时间
 *
 *  @param interval 时间（单位以秒为单位）
 */
+ (void)setDefaultTimeoutInterval:(NSTimeInterval)interval;

+ (void)setDefaultUserAgent:(NSString*)userAgent;

+(NSMutableDictionary*)sharedCacheKeyDict;


@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *basePath;
@property (nonatomic, strong) NSString *userAgent;
@property (nonatomic, readwrite) BOOL sendParametersAsJSON;
@property (nonatomic, readwrite) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, readwrite) NSUInteger timeoutInterval;

@end
