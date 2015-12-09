//
//  Settings.swift
//  HttpClient
//
//  Created by Tyrant on 6/25/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit

class Settings {
    static var key = Setting<String>(name: "key", defaultValue: "")
    static var libraryId = Setting<Int>(name: "libraryId", defaultValue: 0)
    static var mangeId = Setting<Int>(name: "manageId", defaultValue: 0)
}
