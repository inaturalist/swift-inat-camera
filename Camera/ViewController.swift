//
//  ViewController.swift
//  Camera
//
//  Created by Amanda Bullington on 6/28/21.
//

import AVFoundation
import UIKit

// adapted from https://www.youtube.com/watch?v=ZYPNXLABf3c
class ViewController: UIViewController {
    
    let minimumZoom: CGFloat = 1.0
    let maximumZoom: CGFloat = 3.0
    var lastZoomFactor: CGFloat = 1.0
    
    // capture session
    var session: AVCaptureSession?
    // photo output
    let output = AVCapturePhotoOutput()
    // video preview
    let previewLayer = AVCaptureVideoPreviewLayer()
    // shutter button
    private let shutterButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        button.layer.cornerRadius = 50
        button.layer.borderWidth = 10
        button.layer.borderColor = UIColor.white.cgColor
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        view.addSubview(shutterButton)
        checkCameraPermissions()
        
        shutterButton.addTarget(self, action: #selector(didTapTakePhoto), for: .touchUpInside)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinchToZoom(_:)))
            self.view.addGestureRecognizer(pinchRecognizer)
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapToFocus(_:)))
            self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        
        shutterButton.center = CGPoint(x: view.frame.size.width/2,
                                       y: view.frame.size.height - 100)
    }
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            // request
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self?.setUpCamera()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            setUpCamera()
        @unknown default:
            break
        }
    }
    
    private func setUpCamera() {
        let session = AVCaptureSession()
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                
                session.startRunning()
                self.session = session
            }
            catch {
                print(error)
            }
        }
    }
    
    @objc private func didTapTakePhoto() {
        // is this the right spot to set the photo format to JPEG?
        output.capturePhoto(with: AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]),
                            delegate: self)
    }
    
    // pinch-to-zoom adapted from: https://stackoverflow.com/questions/33180564/pinch-to-zoom-camera
    @objc private func pinchToZoom(_ pinch: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        // Return zoom value between the minimum and maximum zoom values
        func minMaxZoom(_ factor: CGFloat) -> CGFloat {
            return min(min(max(factor, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        }

        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                print("\(error.localizedDescription)")
            }
        }

        let newScaleFactor = minMaxZoom(pinch.scale * lastZoomFactor)

        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended:
            lastZoomFactor = minMaxZoom(newScaleFactor)
            update(scale: lastZoomFactor)
        default: break
        }
    }
    
    // adapted from: https://github.com/chrisdanbg/swift-cameraFocus-rectangle/
    @objc func tapToFocus(_ gesture: UITapGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        let touchPoint: CGPoint = gesture.location(in: view)
        let convertedPoint: CGPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(AVCaptureDevice.FocusMode.autoFocus) {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = convertedPoint
                device.focusMode = AVCaptureDevice.FocusMode.autoFocus
                device.unlockForConfiguration()
            } catch {
                print("unable to focus")
            }
        }
        let location = gesture.location(in: view)
        let x = location.x - 40
        let y = location.y - 40
        let lineView = DrawSquare(frame: CGRect(x: x, y: y, width: 150, height: 150))
        lineView.backgroundColor = UIColor.clear
        lineView.alpha = 1.0
        view.addSubview(lineView)
        
        DrawSquare.animate(withDuration: 1.5, animations: {
            lineView.alpha = 0
        }) { (success) in
            lineView.alpha = 0
        }
        
    }

}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error:
        Error?) {
        // do we need to add jpegDataRepresentation to support iOS 10 and below?
        guard let data = photo.fileDataRepresentation() else {
            return
        }
//        let image = UIImage(data: data)

        if let image = UIImage(data:data) {
            print(image)
            if let data = image.jpegData(compressionQuality: 1.0) {
                let filename = getCachesDirectory().appendingPathComponent("\(UUID().uuidString).jpg")
                print(filename)
                try? data.write(to: filename)
                // need to resolve this function with the filename
            } else {
              // handle error
            }
        }
        
        func getCachesDirectory() -> URL {
            let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            return paths[0]
        }
        
        session?.stopRunning()
    }
}

class DrawSquare: UIView {

    override func draw(_ rect: CGRect) {
        let h = rect.height
        let w = rect.width
        let color:UIColor = UIColor.white
        
        let drect = CGRect(x: (w * 0.25),y: (h * 0.25),width: (w * 0.5),height: (h * 0.5))
        let bpath:UIBezierPath = UIBezierPath(rect: drect)
        
        color.set()
        bpath.stroke()
    }

}
