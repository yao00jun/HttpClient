//
//  TxtViewController.swift
//  HttpClient
//
//  Created by Tyrant on 6/23/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit

class TxtViewController: UIViewController {

    var txt:String = ""
    var _lblMain:UILabel?
    var lblMain:UILabel{
        get{
            if _lblMain == nil {
                _lblMain = UILabel()
                _lblMain?.font = UIFont.systemFontOfSize(12)
                _lblMain?.textColor = UIColor.blackColor()
                _lblMain?.numberOfLines = 0
            }
            return _lblMain!
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.whiteColor()
        navigationItem.title = "文本"
        lblMain.frame = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.width, height: UIScreen.mainScreen().bounds.height)
        view.addSubview(lblMain)
        fillData()
        // Do any additional setup after loading the view.
    }
    
    func fillData(){
        lblMain.text = txt
    }
}
