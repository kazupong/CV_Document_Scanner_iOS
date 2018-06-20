//
//  ViewController.swift
//  Doc_Scanner
//
//  Created by Kazuyuki Nakatsu on 6/12/18.
//  Copyright © 2018 Kazuyuki Nakatsu. All rights reserved.
//

/*
 < VisionFramework 矩形検地を使った書類を認識・切り取りするアプリ >
 
   AVFoundationでカメラを起動後、矩形を自動で検出。シャッターボタン
   が押されると、その時検地していた矩形を切り抜く。
   その後、HTTP接続で外部サーバーに送りOCR処理にかけられ、レスポンスの
   jsonをViewに表示する。
 */

import UIKit
import AVFoundation
import ImageIO
import Vision
import CoreGraphics

// apple公式のサンプルコードを使用
extension CGImagePropertyOrientation {
    init(_ orientation: UIImageOrientation) {
        switch orientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        }
    }
}

// 画面上に認識矩形を描画するための custom view
class VisualizeRectanlgesView: UIView {
    
    var rectangles: [CGRect] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    var characterRectangles: [VNRectangleObservation] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    private func convertedPoint(point: CGPoint, to size: CGSize) -> CGPoint {
        // view 上の座標に変換する
        // 座標系変換のため、 Y 軸方向に反転する
        return CGPoint(x: point.x * size.width, y: (1.0 - point.y) * size.height)
    }
    func convertedRect(rect: CGRect, to size: CGSize) -> CGRect {
        // view 上の長方形に変換する
        // 座標系変換のため、 Y 軸方向に反転する
        return CGRect(x: rect.minX * size.width, y: (1.0 - rect.maxY) * size.height, width: rect.width * size.width, height: rect.height * size.height)
    }
    // CGRectにある矩形情報を元に線を引く
    override func draw(_ rect: CGRect) {
        backgroundColor = UIColor.clear
        
        UIColor.red.setStroke()
        
        for rect in rectangles {
            let path = UIBezierPath(rect: convertedRect(rect: rect, to: frame.size))
            path.lineWidth = 5
            path.stroke()
        }
    }
}

class ViewController: UIViewController {
    
    // outlets
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var backGround: UIImageView!
    
    
    // メンバ
    var photo2:CGImage?
    var photo:UIImage?
    private var session: AVCaptureSession?
    private let visualizeRectanglesView =
        VisualizeRectanlgesView(frame: CGRect.zero)
    
    // ビューの life circle ロード時の処理
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(visualizeRectanglesView)
    }
    // ビューの life circle ロード後の処理
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupAndStartAVCaptureSession()
    }
    // ビューの life circle ビューの処理が終わる時の処理
    override func viewWillDisappear(_ animated: Bool) {
        stopAVCaptureSession()
        super.viewWillDisappear(animated)
    }
    
    // 画面中央下のシャッターボタンが押された時のアクション
    @IBAction func photoButtonPressed(_ sender: Any) {
        performSegue(withIdentifier: "preview", sender: nil)
    }
    //次にsegueに遷移する時用の処理
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "preview" {
            if let vc = segue.destination as? PreviewViewController {
                vc.image = self.photo
            }
        }
    }
    
    // カメラの設定と起動用の処理
    private func setupAndStartAVCaptureSession() {
        session = AVCaptureSession()
        session?.sessionPreset = AVCaptureSession.Preset.photo
        
        let device = AVCaptureDevice.default(for: AVMediaType.video)
        let input = try! AVCaptureDeviceInput(device: device!)
        session?.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        output.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: DispatchQoS.QoSClass.default))
        session?.addOutput(output)
        
        session?.startRunning()
    }
    // カメラの修理処理
    private func stopAVCaptureSession() {
        session?.stopRunning()
    }
    //crop処理
    func cropImage(_ inputImage: UIImage, toRect cropRect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage?
    {
        let imageViewScale = max(inputImage.size.width / viewWidth,
                                 inputImage.size.height / viewHeight)
        
        // Scale cropRect to handle images larger than shown-on-screen size
        let cropZone = CGRect(x:cropRect.origin.x * imageViewScale,
                              y:cropRect.origin.y * imageViewScale,
                              width:cropRect.size.width * imageViewScale,
                              height:cropRect.size.height * imageViewScale)
        
        // Perform cropping in Core Graphics
        guard let cutImageRef: CGImage = inputImage.cgImage?.cropping(to:cropZone)
            else {
                return nil
        }
        
        // Return image to UIImage
        let croppedImage: UIImage = UIImage(cgImage: cutImageRef,scale:inputImage.scale, orientation: .right)
        return croppedImage
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // UIViewController#view 上の画像表示領域 (frame) を計算する
    private func imageFrameOnViewController(uiImage: UIImage) -> CGRect {
        let imageAspectRatio = uiImage.size.width / uiImage.size.height
        let viewAspectRatio = imageView.bounds.width / imageView.bounds.height
        if imageAspectRatio > viewAspectRatio {
            let ratio = imageView.bounds.width / uiImage.size.width
            return CGRect(
                x: imageView.frame.minX + 0,
                y: imageView.frame.minY + (imageView.bounds.height - ratio * uiImage.size.height) * 0.5,
                width: imageView.bounds.width,
                height: ratio * uiImage.size.height)
        } else {
            let ratio = view.bounds.height / uiImage.size.height
            return CGRect(
                x: imageView.frame.minX + (imageView.bounds.width - ratio * uiImage.size.width) * 0.5,
                y: imageView.frame.minY + 0,
                width: ratio * uiImage.size.width,
                height: imageView.bounds.height)
        }
    }
    // カメラで撮った映像をUIImageへ
    func sampleBufferToUIImage(sampleBuffer: CMSampleBuffer, with orientation: UIInterfaceOrientation) -> UIImage {
        let  imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        CVPixelBufferLockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer!)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer!)
        let width = CVPixelBufferGetWidth(imageBuffer!)
        let height = CVPixelBufferGetHeight(imageBuffer!)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        let quartzImage = context?.makeImage()
        CVPixelBufferUnlockBaseAddress(imageBuffer!, CVPixelBufferLockFlags.readOnly)
        
        // rear カメラの sampleBuffer は landscapeRight の向きなので、ここで orientation を補正
        if orientation == .landscapeLeft {
            return UIImage(cgImage: quartzImage!, scale: 1.0, orientation: .down)
        } else if orientation == .landscapeRight {
            return UIImage(cgImage: quartzImage!, scale: 1.0, orientation: .up)
        } else {
            return UIImage(cgImage: quartzImage!, scale: 1.0, orientation: .right)
        }
    }
    // 撮った映像と矩形の処理をする
    func captureOutput(_ output: AVCaptureOutput!, didOutput sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        let uiImage = sampleBufferToUIImage(sampleBuffer: sampleBuffer, with: UIApplication.shared.statusBarOrientation)
        let orientation = CGImagePropertyOrientation(uiImage.imageOrientation)
        let ciImage = CIImage(image: uiImage)!
        
        // UI の変更はメインスレッドで実行
        DispatchQueue.main.async { [weak self] in
            if let frame = self?.imageFrameOnViewController(uiImage: uiImage) {
                self?.imageView.image = uiImage
                self?.visualizeRectanglesView.frame = frame
            }
        }
        // RequestHandlerの設定　(*orientation を必ず設定すること)
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: CGImagePropertyOrientation(rawValue: CGImagePropertyOrientation.RawValue(Int32(orientation.rawValue)))!)
        
        let request = VNDetectRectanglesRequest() { request, error in
            
            // 矩形を取得
            let rects = request.results?.flatMap { result -> [CGRect] in
                
                guard let observation = result as? VNRectangleObservation else { return [] }
                
                // 画像を一時保存的に保存して解析frameを統一
                var temp_image   =  uiImage
                let image_width  =  uiImage.size.width
                let image_height =  uiImage.size.height
                
                // 画像と矩形の座標を元にCrop処理する
                var rect_crop: CGRect = CGRect(  x: observation.boundingBox.minX            * (image_width ),
                                                 y: (1.0 - observation.boundingBox.maxY)    * (image_height),
                                                 width: observation.boundingBox.width       * (image_width ),
                                                 height: observation.boundingBox.height     * (image_height))
                // Crop処理
                self.photo = temp_image.cropping(to: rect_crop)
                
                return [observation.boundingBox]
                } ?? []
            
            // UI の変更はメインスレッドで実行(並列処理)
            DispatchQueue.main.async { [weak self] in
                self?.visualizeRectanglesView.rectangles = rects
            }
        }
        // リクエストに詳細設定
        request.maximumObservations = 1     // 認識する矩形の数の最大値
        request.minimumAspectRatio  = 0.2   // 認識対象とする矩形のアスペクト比（長辺と短編の比率）
        try! handler.perform([request])
    }
}
// UIImageにCrop処理をするclass methodを追加
extension UIImage {
    
    func cropping(to: CGRect) -> UIImage? {
        var opaque = false
        
        if let cgImage = cgImage {
            switch cgImage.alphaInfo {
            case .noneSkipLast, .noneSkipFirst:
                opaque = true
            default:
                break
            }
        }
        UIGraphicsBeginImageContextWithOptions(to.size, opaque, 0.0)
        //scalingはここで可能
        draw(at: CGPoint(x: -to.origin.x, y: -to.origin.y))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}
