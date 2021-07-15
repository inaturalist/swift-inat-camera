//
//  ViewController.swift
//  Camera
//
//  Created by Amanda Bullington on 6/28/21.
//

import AVFoundation
import UIKit

@objc(ViewController)
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
        let shutterButtonWidth: CGFloat = 100
        let shutterButtonCoordinate: CGFloat = 0
        let cornerRadius: CGFloat = 50
        let borderWidth: CGFloat = 10

        let button = UIButton(frame: CGRect(x: shutterButtonCoordinate, y: shutterButtonCoordinate, width: shutterButtonWidth, height: shutterButtonWidth))
        button.layer.cornerRadius = cornerRadius
        button.layer.borderWidth = borderWidth
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
        let shutterXCoord = view.frame.size.width/2
        let shutterYCoord = view.frame.size.height - 100

        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        
        shutterButton.center = CGPoint(x: shutterXCoord, y: shutterYCoord)
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
        let animationDuration: TimeInterval = 1.5
        let squareWidth: CGFloat = 150
        let transparent: CGFloat = 0
        let visible: CGFloat = 1.0
        // this offset makes the focus box appear under the user's finger
        let offset: CGFloat = 40

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
        let x = location.x - offset
        let y = location.y - offset
        let lineView = DrawSquare(frame: CGRect(x: x, y: y, width: squareWidth, height: squareWidth))
        lineView.backgroundColor = UIColor.clear
        lineView.alpha = visible
        view.addSubview(lineView)
        
        DrawSquare.animate(withDuration: animationDuration, animations: {
            lineView.alpha = transparent
        }) { (success) in
            lineView.alpha = transparent
        }
        
    }

}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error:
        Error?) {
        let highestQuality: CGFloat = 1.0

        // do we need to add jpegDataRepresentation to support iOS 10 and below?
        guard let data = photo.fileDataRepresentation() else {
            return
        }

        if let image = UIImage(data:data) {
            print(image)
            if let data = image.jpegData(compressionQuality: highestQuality) {
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
        // these multipliers control how the tap-to-focus square is displayed
        let coordMultiplier: CGFloat = 0.25
        let dimensionMultiplier: CGFloat = 0.5

        let h = rect.height
        let w = rect.width
        let color:UIColor = UIColor.white
        
        let drect = CGRect(x: (w * coordMultiplier), y: (h * coordMultiplier), width: (w * dimensionMultiplier), height: (h * dimensionMultiplier))
        let bpath:UIBezierPath = UIBezierPath(rect: drect)
        
        color.set()
        bpath.stroke()
    }

}
