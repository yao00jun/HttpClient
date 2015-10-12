//
//  Setting.swift
//  TouchTest
//
//  Created by Tyrant on 6/4/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit

class Setting<T>
{
    private var name:String!
    private var value:T?
    private var defaultValue:T?
    private var hasValue:Bool = false
    private var timeOutData:NSDate?
    private var storeLevel:Int = 0
    
    init(name:String,defaultValue:T) {
        self.name = name;
        self.defaultValue = defaultValue;
        storeLevel = self.getStoreLevel()
    }
    
    var Value:T
    {
        get
        {
            if !hasValue
            {
                if storeLevel == 0 //如果存储等级为0,那么从userdefault取
                {
                    if Setting.settingData().objectForKey(name) == nil //如果取不出来
                    {
                        self.value = self.defaultValue;
                        Setting.settingData().setObject(self.value! as? AnyObject, forKey: self.name)
                        Setting.settingData().synchronize()
                        hasValue = true
                    }
                    else
                    {
                        self.value = Setting.settingData().objectForKey(self.name) as? T
                        hasValue = true
                    }
                }
                if storeLevel == 1 //这是用归档保存, 日后处理
                {
                        self.value = self.defaultValue;
                }
            }
            return self.value!
        }
        set
        {
            self.value = newValue
            if storeLevel == 0
            {
                Setting.settingData().setObject(self.value! as? AnyObject, forKey: self.name)
                Setting.settingData().synchronize()
            }
            if storeLevel == 1  //这是用归档保存, 日后处理
            {
                
            }
            hasValue = true
        }
    }
    
    internal func clear(){
        hasValue = false
        Setting.settingData().removeObjectForKey(self.name)
    }
    
    private func getStoreLevel()->Int
    {
        _ = Mirror(reflecting: self.defaultValue!);
        if self.defaultValue! is Int || self.defaultValue! is String || self.defaultValue! is NSDate || self.defaultValue! is Bool || self.defaultValue! is Float
        {
           return 0
        }
        return 1
    }
    
    
    
   private static func settingData()->NSUserDefaults
    {
        return NSUserDefaults.standardUserDefaults()
    }
}
