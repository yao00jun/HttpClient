//
//  ViewController.swift
//  HttpClient
//
//  Created by 123 on 6/22/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var img: UIImageView!
    @IBOutlet weak var lbl: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
       
        // Do any additional setup after loading the view, typically from a nib.
    }
    @IBAction func requestImage(sender: AnyObject) {
        HttpClient.get("http://img1.gamersky.com/image2015/06/20150614ydx_8/image089.jpg", parameters: nil, cache: 0, cancelToken: nil) { (response, urlResponse, error) -> () in
            if let i = UIImage(data: response as! NSData){
                self.img.image = i
            }
        }
    }

    @IBAction func request(sender: UIButton) {
        HttpClient.get("http://www.baidu.com", parameters: nil, cache: 0, cancelToken: nil) { (response, urlResponse, error) -> () in
            if let str = NSString(data: response as! NSData, encoding: NSUTF8StringEncoding){
                self.lbl.text = str as String
            }
        }
    }
}

