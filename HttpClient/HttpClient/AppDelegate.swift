//
//  AppDelegate.swift
//  HttpClient
//
//  Created by 123 on 6/22/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        HttpClient.setGlobalCachePolicy(NSURLRequestCachePolicy.UseProtocolCachePolicy)  // cache policy, the default value is NSURLRequestCachePolicy.UseProtocolCachePolicy
        HttpClient.setGlobalNeedSendParametersAsJSON(false) // send post value as json the default value is false
        HttpClient.setGlobalUsername("httpclient") //set request authentication username，default is nil (i have't test this feature)
        HttpClient.setGlobalPassword("123456") //set request authentication password，default is nil (i have't test this feature)
        HttpClient.setGlobalTimeoutInterval(40) // set request time out ,the default value is 20
        HttpClient.setGlobalUserAgent("Firefox") // set User Agent the default if HttpClient
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.width, height: UIScreen.mainScreen().bounds.size.height))
        var vc = ViewController()
        var rootNavigationController = UINavigationController(rootViewController: vc)
        window?.rootViewController = rootNavigationController
        window?.makeKeyAndVisible()
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

