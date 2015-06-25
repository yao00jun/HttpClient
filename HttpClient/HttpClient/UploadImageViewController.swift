//
//  UploadImage.swift
//  HttpClient
//
//  Created by Tyrant on 6/25/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit
import AssetsLibrary
class UploadImageViewController: UIViewController {
    var _imgUpload:UIImageView?
    var imgUpload:UIImageView{
        if _imgUpload == nil{
            _imgUpload = UIImageView()
            _imgUpload?.contentMode = UIViewContentMode.ScaleAspectFit
        }
        return _imgUpload!
    }
    var _progressUploadImage:UIProgressView?
    var progressUploadImage:UIProgressView{
        if _progressUploadImage == nil{
            _progressUploadImage = UIProgressView(progressViewStyle: UIProgressViewStyle.Bar)
            _progressUploadImage?.progressTintColor = UIColor.blueColor()
        }
        return _progressUploadImage!
    }
    var _segImageType:UISegmentedControl?
    var segImageType:UISegmentedControl{
        if _segImageType == nil{
            _segImageType  = UISegmentedControl(items: ["JPG","PNG","GIF"])
            _segImageType?.addTarget(self, action: "segChoose:", forControlEvents: UIControlEvents.ValueChanged)
        }
        return _segImageType!
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        imgUpload.frame = CGRect(x: 0, y: 120, width: UIScreen.mainScreen().bounds.width, height: UIScreen.mainScreen().bounds.width)
        imgUpload.image = UIImage(named: "upload1")
        view.addSubview(imgUpload)
        progressUploadImage.frame = CGRect(x: 0, y: 70, width: UIScreen.mainScreen().bounds.width, height: 20)
        view.addSubview(progressUploadImage)
        view.backgroundColor = UIColor.whiteColor()
        navigationItem.title = "上传图片"
        var btnUpload = UIBarButtonItem(title: "上传", style: UIBarButtonItemStyle.Plain, target: self, action: "upload")
        var btnCancel = UIBarButtonItem(title: "取消", style: UIBarButtonItemStyle.Plain, target: self, action: "cancel")
        navigationItem.rightBarButtonItems = [btnCancel,btnUpload]
        segImageType.frame = CGRect(x: 0, y: 120, width: UIScreen.mainScreen().bounds.width, height: 30)
        segImageType.selectedSegmentIndex = 0
        view.addSubview(segImageType)
    }
    
    func upload(){
        var imgData:NSData?
        if segImageType.selectedSegmentIndex == 0
        {
            imgData = UIImageJPEGRepresentation(imgUpload.image!, 0.3)
        }
        else if segImageType.selectedSegmentIndex == 1{
            imgData = UIImagePNGRepresentation(imgUpload.image)
        }
        else{
             //暂时无法将gif图片转成gif的nsdata
        }
        var dict = ["ImageTitle":"我的好东西","Label":"我的麒麟臂把持不住了","test1":NSNumber(double: 1.1),"test2":NSNumber(int: 11),"test3":NSNumber(bool: true),"image0":imgData!]
       // var dict = ["image0":imgData!]
        var option = [HttpClientOption.TimeOut:NSNumber(int: 15)]
        var url = "http://api.qingfanqie.com/InLibraryConsole/Showcase/UploadWindow/\(Settings.mangeId.Value)/\(Settings.key.Value)/\(Settings.libraryId.Value)"
        HttpClient.Post(url, parameters: dict, cancelToken: "img", queryPara: nil, requestOptions: option, headerFields: nil, progress: { (progress) -> () in
            println(progress)
            self.progressUploadImage.progress = Float(progress)
        }) { (response, urlResponse, error) -> () in
            if error != nil{
                println("there is a error\(error)")
                return
            }
            if let data = response as? NSData{
                if let result = NSString(data: data, encoding: NSUTF8StringEncoding){
                    println(result)
                }
            }

        }
    }
    
    func cancel(){
        
    }
    
    func segChoose(sender:UISegmentedControl){
        var index = sender.selectedSegmentIndex
        switch index{
            case 0:         imgUpload.image = UIImage(named: "upload4")
                    case 1:         imgUpload.image = UIImage(named: "upload2")
                    case 2:         imgUpload.image = UIImage(named: "upload3.gif")
        default: break
        }
    }
    
}
