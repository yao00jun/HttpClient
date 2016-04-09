//
//  ImgViewController.swift
//  HttpClient
//
//  Created by Tyrant on 6/23/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit

class ImgViewController: UIViewController {
    
    var img:UIImage?
    var _imgMain:UIImageView?
    var imgMain:UIImageView{
        get{
            if _imgMain == nil {
                _imgMain = UIImageView()
                _imgMain?.contentMode = UIViewContentMode.ScaleAspectFill
            }
            return _imgMain!
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.whiteColor()
        navigationItem.title = "图片"
        imgMain.frame = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.width, height: UIScreen.mainScreen().bounds.height)
        view.addSubview(imgMain)
        imgMain.contentMode = UIViewContentMode.ScaleAspectFit
        fillData()
        // Do any additional setup after loading the view.
    }
    
    func fillData(){
        imgMain.image = img
    }


}
