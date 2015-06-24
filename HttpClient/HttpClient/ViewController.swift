//
//  ViewController.swift
//  HttpClient
//
//  Created by 123 on 6/22/15.
//  Copyright (c) 2015 Tyrant. All rights reserved.
//

import UIKit

class ViewController: UIViewController,UITableViewDelegate,UITableViewDataSource,NSURLConnectionDataDelegate {
     let cellIdentity:String = "cell"
    var arrStrs:[String] = [String]()
    var _tbMain:UITableView?
    var tbMain:UITableView{
        get{
            if _tbMain == nil{
                _tbMain = UITableView()
                _tbMain?.delegate = self
                _tbMain?.dataSource = self
                _tbMain?.separatorStyle = UITableViewCellSeparatorStyle.None
            }
            return _tbMain!
        }
    }
    var dataStream:NSMutableData?
    override func viewDidLoad() {
        super.viewDidLoad()
        HttpClient.setGlobalTimeoutInterval(NSTimeInterval(40))
        arrStrs.append("get")
        arrStrs.append("getImage")
        arrStrs.append("getImageWithProgress")
        view.backgroundColor = UIColor.whiteColor()
        navigationItem.title = "操作"
        tbMain.frame = CGRect(x: 0, y: 0, width: UIScreen.mainScreen().bounds.size.width, height: UIScreen.mainScreen().bounds.height - 50)
        view.addSubview(tbMain)
        var btnBar = UIBarButtonItem(title: "取消", style: UIBarButtonItemStyle.Plain, target: self, action: "cancelRequest")
        var btnClearCache = UIBarButtonItem(title: "缓存", style: UIBarButtonItemStyle.Plain, target: self, action: "clearCache")
        navigationItem.rightBarButtonItems = [btnBar,btnClearCache]

    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return arrStrs.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier(cellIdentity) as? UITableViewCell
        if cell == nil{
            cell = UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: cellIdentity)
        }
        cell?.textLabel?.text = arrStrs[indexPath.row]
        return cell!
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var str = arrStrs[indexPath.row]
        switch (str){
        case "get":
            HttpClient.get("http://www.baidu.com", parameters: nil, cache: 20, cancelToken: nil, complettion: { (response, urlResponse, error) -> () in
                if error != nil{
                    println("there is a error\(error)")
                    return
                }
                if let data = response as? NSData{
                    if let result = NSString(data: data, encoding: NSUTF8StringEncoding){
                        var tvc = TxtViewController()
                        tvc.txt = result as String
                        self.navigationController?.pushViewController(tvc, animated: true)
                    }
                }
            })
            case "getImage":
                var path: AnyObject? = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true).first
                var myPath = (path as! NSString).stringByAppendingPathComponent("img.jpg")
                var httpOption = [HttpClientOption.SavePath:myPath,HttpClientOption.TimeOut:NSNumber(int: 100)]
                
            HttpClient.get("http://img1.gamersky.com/image2015/05/20150523ge_4/gamersky_10origin_19_20155231446302.jpg", parameters: nil, cache: 100, cancelToken: "img", requestOptions: httpOption, headerFields: nil, progress: { (progress) -> () in
                println(progress)
            }, complettion: { (response, urlResponse, error) -> () in
                if error != nil{
                    println("there is a error\(error)")
                    return
                }
                if let data = response as? NSData{
                    if let result = UIImage(data: data){
                        var tvc = ImgViewController()
                        tvc.img = result
                        self.navigationController?.pushViewController(tvc, animated: true)
                    }
                }

            })
        default: break
        }
    }
    
    
    func cancelRequest(){
        HttpClient.cancelRequestWithIndentity("img")
        var request = NSMutableURLRequest(URL:NSURL(string: "http://www.baidu.com")!, cachePolicy: NSURLRequestCachePolicy.ReturnCacheDataElseLoad, timeoutInterval: 50)
        var conn = NSURLConnection(request: request, delegate: self, startImmediately: false)
                dataStream = NSMutableData()
        conn?.start()
    }
    
    func clearCache(){
        HttpClient.clearCache()
    }
    
    func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        dataStream?.appendData(data)
    }
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        println("error\(error)")
    }
    func connectionDidFinishLoading(connection: NSURLConnection) {
        var str = NSString(data: dataStream!, encoding: NSUTF8StringEncoding)
        println("finish load\(str)")
    }
    
    
}

