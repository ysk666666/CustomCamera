//
//  ViewController.swift
//  CustomCamera
//
//  Created by ysk on 2017/7/31.
//  Copyright © 2017年 ysk. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class ViewController: UIViewController {
    
    let captureSession: AVCaptureSession = AVCaptureSession()
    var captureDeviceInput: AVCaptureDeviceInput!
    let captureStillImageOutput: AVCaptureStillImageOutput = AVCaptureStillImageOutput()
    let captureVideoDataOutput: AVCaptureVideoDataOutput = AVCaptureVideoDataOutput()
    var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    var outputSampleBuffer: CMSampleBuffer?
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //设置session的清晰度
        if captureSession.canSetSessionPreset(AVCaptureSessionPresetHigh) {
            captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        }
        //获取输入的设备，后置摄像头
        do {
            try captureDeviceInput = AVCaptureDeviceInput(device: getCameraDeviceWithPosition(AVCaptureDevicePosition.back))
        } catch let error as NSError {
            print("error: \(error)")
        }
        captureSession.addInput(captureDeviceInput)
        
        //图片输出
        captureStillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        captureSession.addOutput(captureStillImageOutput)
        
        //视频数据输出
        captureVideoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "yskVideoBuffer"))
        captureSession.addOutput(captureVideoDataOutput)
        captureSession.startRunning()
        
        captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        captureVideoPreviewLayer.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height)
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspect
        let cameraPreview = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height))
        cameraPreview.layer.addSublayer(captureVideoPreviewLayer)
//        cameraPreview.backgroundColor = UIColor.clear
        cameraPreview.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.savePhoto(_:))))
        self.view.addSubview(cameraPreview)
    }
    
    func savePhoto(_ sender: UITapGestureRecognizer) -> Void {
        //通过AVCaptureStillImageOutput获取图像，会有声音
//        if let videoConnection = captureStillImageOutput.connection(withMediaType: AVMediaTypeVideo) {
//            captureStillImageOutput.captureStillImageAsynchronously(from: videoConnection, completionHandler: { (imageDataSampleBuffer, error) in
//                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
//                UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData!)!, nil, nil, nil)
//            })
//        }
        
        //通过图片缓存获取图像，没有声音
        if self.outputSampleBuffer != nil {
            let image = self.imageFromSampleBuffer(self.outputSampleBuffer!)
            
            //使用UIKit框架的最传统的方式保存片
//            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
            
            for view in self.view.subviews {
                if view is UIImageView {
                    view.removeFromSuperview()
                }
            }
            let imageview = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            imageview.image = image
            self.view.addSubview(imageview)
            
            //通过Photos库保存照片到库，适用于iOS8以上
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == PHAuthorizationStatus.authorized {
                    PHPhotoLibrary.shared().performChanges({
                        let req: PHAssetChangeRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                        print(req.placeholderForCreatedAsset?.localIdentifier as Any)
                    }, completionHandler: { (success, error) in
                        if success {
                            print("保存成功")
                        } else {
                            print("保存失败\(error.debugDescription)")
                        }
                    })
                }
            })
            
        }
    }
    
    //MARK : - private methord
    func getCameraDeviceWithPosition(_ position: AVCaptureDevicePosition) -> AVCaptureDevice {
        let cameras = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo)
        for camera in cameras! {
            if (camera as? AVCaptureDevice)?.position == position {
                return camera as! AVCaptureDevice
            }
        }
        return cameras?.first as! AVCaptureDevice
    }
    
    func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) -> Void {
        if error == nil {
            print("保存成功")
        } else {
            print("保存出错: \(String(describing: error?.description))")
        }
    }
    
    func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage {
        let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        var outCIImage = CIImage(cvImageBuffer: imageBuffer)
        
        let orientation = UIDevice.current.orientation
        var t: CGAffineTransform!
        if orientation == UIDeviceOrientation.portrait {
            t = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        } else if orientation == UIDeviceOrientation.portraitUpsideDown {
            t = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2.0))
        } else if (orientation == UIDeviceOrientation.landscapeRight) {
            t = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
        } else {
            t = CGAffineTransform(rotationAngle: 0)
        }
        outCIImage = outCIImage.applying(t)
        
        let eaglContext = EAGLContext(api: EAGLRenderingAPI.openGLES2)
        let options = [kCIContextWorkingColorSpace : NSNull()]
        let context = CIContext(eaglContext: eaglContext!, options: options)
        let cgImage = context.createCGImage(outCIImage, from: outCIImage.extent)
        let returnImage = UIImage(cgImage: cgImage!)
        return returnImage
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        self.outputSampleBuffer = sampleBuffer
    }
}
