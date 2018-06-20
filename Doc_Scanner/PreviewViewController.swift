//
//  PreviewViewController.swift
//  Doc_Scanner
//
//  Created by Kazuyuki Nakatsu on 6/12/18.
//  Copyright © 2018 Kazuyuki Nakatsu. All rights reserved.
//


import UIKit
import Foundation


class PreviewViewController: UIViewController {
    
    // outlets
    @IBOutlet weak var imageView: UIImageView! // 画像表示用
   
    @IBOutlet weak var textField: UITextView!
    
    //メンバ
    var image:UIImage? // crop処理後の画像
    
    // main
    override func viewDidLoad() {
        super.viewDidLoad()
        self.imageView.image = self.image  // 画像をimageViewに貼り付け
        
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    //キャンセルボタンが押された時のアクション
    @IBAction func cancelButton(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    //sendボタンが押された時のアクション
    @IBAction func sendButtonClicked(_ sender: Any) {
        
        let imageData:Data = UIImagePNGRepresentation(image!)!
        let imageStr = imageData.base64EncodedString()
        
    
        //----------  HTTP MultiPartのリクエスト ---------------
        
        let urlSessionMultipartClient = URLSessionMulitipartClient()
        let parameters = [ "image": imageStr] as [String : Any]
        urlSessionMultipartClient.mulipartPost(url: "http://localhost:4567", parameters: parameters)
        
        //---------- HTTP GETのアクションのリクエスト -------------
        let urlSessionGetClient = URLSessionGetClient()
        let queryItems = [URLQueryItem(name: "a", value: "foo"),
                          URLQueryItem(name: "b", value: "1234")]
        urlSessionGetClient.get(url: "http://localhost:4567/sushi.json", queryItems: queryItems)
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
    
}

// ----- Multi Part (Jpeg画像のPOST) -----
class URLSessionMulitipartClient {
    
    func mulipartPost(url urlString: String, parameters: [String: Any]) {
        let url = URL(string: urlString)
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        
        let uniqueId = ProcessInfo.processInfo.globallyUniqueString
        let boundary = "---------------------------\(uniqueId)"
        
        // Headerの設定
        request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Bodyの設定
        var body = Data()
        var bodyText = String()
        
        for element in parameters {
            switch element.value {
            case let image as UIImage:
                let imageData = UIImageJPEGRepresentation(image, 1.0)
                bodyText += "--\(boundary)\r\n"
                bodyText += "Content-Disposition: form-data; name=\"\(element.key)\"; filename=\"\(element.key).jpg\"\r\n"
                bodyText += "Content-Type: image/jpeg\r\n\r\n"
                
                body.append(bodyText.data(using: String.Encoding.utf8)!)
                body.append(imageData!)
            case let int as Int:
                bodyText = String()
                bodyText += "--\(boundary)\r\n"
                bodyText += "Content-Disposition: form-data; name=\"\(element.key)\";\r\n"
                bodyText += "\r\n"
                
                body.append(bodyText.data(using: String.Encoding.utf8)!)
                body.append(String(int).data(using: String.Encoding.utf8)!)
            case let string as String:
                bodyText += "--\(boundary)\r\n"
                bodyText += "Content-Disposition: form-data; name=\"\(element.key)\";\r\n"
                bodyText += "\r\n"
                
                body.append(bodyText.data(using: String.Encoding.utf8)!)
                body.append(string.data(using: String.Encoding.utf8)!)
            default:
                break
            }
        }
        
        // Footerの設定
        var footerText = String()
        footerText += "\r\n"
        footerText += "\r\n--\(boundary)--\r\n"
        
        body.append(footerText.data(using: String.Encoding.utf8)!)
        
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let response = response {
                print(response)
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
                    print(json)
                } catch {
                    print("Serialize Error")
                }
            } else {
                print(error ?? "Error")
            }
        }
        
        task.resume()
    }
}

// ---------------------- GET ---------------------------------
class URLSessionGetClient {
    
    func get(url urlString: String, queryItems: [URLQueryItem]? = nil) {
        var compnents = URLComponents(string: urlString)
        compnents?.queryItems = queryItems
        let url = compnents?.url
        let task = URLSession.shared.dataTask(with: url!) { data, response, error in
            if let data = data, let response = response {
                print(response)
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments)
                    print(json)
                } catch {
                    print("Serialize Error")
                }
            } else {
                print(error ?? "Error")
            }
        }
        
    task.resume()
    }
    
}


public enum ImageFormat {
    case png
    case jpeg(CGFloat)
}
extension UIImage {
    
    public func base64(format: ImageFormat) -> String? {
        var imageData: Data?
        switch format {
        case .png: imageData = UIImagePNGRepresentation(self)
        case .jpeg(let compression): imageData = UIImageJPEGRepresentation(self, compression)
        }
        return imageData?.base64EncodedString()
    }
}

