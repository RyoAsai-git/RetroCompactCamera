import AVFoundation
import UIKit
import Photos

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didCapturePhoto image: UIImage)
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error)
    func cameraManagerDidStartRunning(_ manager: CameraManager)
    func cameraManagerDidStopRunning(_ manager: CameraManager)
}

class CameraManager: NSObject {
    
    // MARK: - Properties
    
    weak var delegate: CameraManagerDelegate?
    
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }
    
    private(set) var isSessionRunning = false
    private var setupResult: SessionSetupResult = .success
    
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    // MARK: - Session Configuration
    
    private func configureSession() {
        print("CameraManager: configureSession called")
        if setupResult != .success {
            print("CameraManager: Setup result not success, returning")
            return
        }
        
        captureSession.beginConfiguration()
        
        // カメラの設定
        captureSession.sessionPreset = .photo
        print("CameraManager: Session preset set to photo")
        
        // ビデオデバイスの追加
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
                print("CameraManager: Using dual camera device")
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
                print("CameraManager: Using back wide angle camera")
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                defaultVideoDevice = frontCameraDevice
                print("CameraManager: Using front camera")
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("CameraManager: Default video device is unavailable.")
                setupResult = .configurationFailed
                captureSession.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                print("Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                captureSession.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            captureSession.commitConfiguration()
            return
        }
        
        // 写真出力の追加
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.commitConfiguration()
        print("CameraManager: Session configuration completed successfully")
    }
    
    // MARK: - Session Control
    
    func startSession() {
        print("CameraManager: startSession called")
        sessionQueue.async {
            print("CameraManager: Setup result is \(self.setupResult)")
            switch self.setupResult {
            case .success:
                print("CameraManager: Starting capture session...")
                self.captureSession.startRunning()
                self.isSessionRunning = self.captureSession.isRunning
                print("CameraManager: Session running: \(self.isSessionRunning)")
                
                DispatchQueue.main.async {
                    self.delegate?.cameraManagerDidStartRunning(self)
                }
                
            case .notAuthorized:
                print("CameraManager: Not authorized")
                DispatchQueue.main.async {
                    let error = NSError(domain: "CameraManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "カメラへのアクセスが許可されていません"])
                    self.delegate?.cameraManager(self, didFailWithError: error)
                }
                
            case .configurationFailed:
                print("CameraManager: Configuration failed")
                DispatchQueue.main.async {
                    let error = NSError(domain: "CameraManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "カメラの設定に失敗しました"])
                    self.delegate?.cameraManager(self, didFailWithError: error)
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            if self.setupResult == .success {
                self.captureSession.stopRunning()
                self.isSessionRunning = self.captureSession.isRunning
                
                DispatchQueue.main.async {
                    self.delegate?.cameraManagerDidStopRunning(self)
                }
            }
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() {
        let photoSettings = AVCapturePhotoSettings()
        
        if videoDeviceInput?.device.isFlashAvailable == true {
            photoSettings.flashMode = .auto
        }
        
        photoSettings.isHighResolutionPhotoEnabled = true
        
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }
        
        sessionQueue.async {
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    // MARK: - Focus and Exposure
    
    func focusAndExpose(at point: CGPoint) {
        sessionQueue.async {
            guard let device = self.videoDeviceInput?.device else { return }
            
            do {
                try device.lockForConfiguration()
                
                // フォーカス設定
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                
                // 露出設定
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                
                device.unlockForConfiguration()
                
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
    // MARK: - Authorization
    
    func checkCameraAuthorization(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
            
        default:
            completion(false)
        }
    }
    
    // MARK: - Device Access
    
    func getCurrentDevice() -> AVCaptureDevice? {
        return videoDeviceInput?.device
    }
    
    // MARK: - Camera Switching
    
    func switchCamera() {
        sessionQueue.async {
            guard let currentInput = self.videoDeviceInput else { return }
            
            let currentPosition = currentInput.device.position
            let preferredPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
            
            guard let newDevice = self.videoDevice(for: preferredPosition) else {
                print("Failed to find camera device for position: \(preferredPosition)")
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                
                self.captureSession.beginConfiguration()
                self.captureSession.removeInput(currentInput)
                
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoDeviceInput = newInput
                } else {
                    self.captureSession.addInput(currentInput)
                    print("Could not add new camera input")
                }
                
                self.captureSession.commitConfiguration()
                
            } catch {
                print("Error switching cameras: \(error)")
            }
        }
    }
    
    private func videoDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInDualCamera,
            .builtInTrueDepthCamera
        ]
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: position
        )
        
        return discoverySession.devices.first
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error {
            DispatchQueue.main.async {
                self.delegate?.cameraManager(self, didFailWithError: error)
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            let error = NSError(domain: "CameraManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "写真データの処理に失敗しました"])
            DispatchQueue.main.async {
                self.delegate?.cameraManager(self, didFailWithError: error)
            }
            return
        }
        
        DispatchQueue.main.async {
            self.delegate?.cameraManager(self, didCapturePhoto: image)
        }
    }
}
