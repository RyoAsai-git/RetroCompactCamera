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
    
    private var _previewLayer: AVCaptureVideoPreviewLayer?
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        return _previewLayer
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
            
            // 写真出力の設定
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            // 自動シャッター音を無効化（重複を防ぐため）
            photoOutput.isLivePhotoCaptureEnabled = false
            
            // セッションの音声設定を無効化してシステムの自動シャッター音を防ぐ
            captureSession.automaticallyConfiguresApplicationAudioSession = false
            
            // サポートされているフォーマットを確認
            if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                print("CameraManager: JPEG codec is available")
            } else {
                print("CameraManager: JPEG codec is not available")
            }
            
            print("CameraManager: Photo output added successfully")
            
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.commitConfiguration()
        print("CameraManager: Session configuration completed successfully")
        
        // Preview layerの初期化
        _previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        _previewLayer?.videoGravity = .resizeAspectFill
        print("CameraManager: Preview layer initialized")
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
        capturePhoto(with: .auto)
    }
    
    func capturePhoto(with flashMode: AVCaptureDevice.FlashMode) {
        // 現在のデバイスのフォーマットを取得
        guard let device = videoDeviceInput?.device else {
            print("No video device available for photo capture")
            return
        }
        
        // デバイスのフォーマットを使用してPhotoSettingsを作成
        let photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        
        // フラッシュ設定を適用
        if device.isFlashAvailable {
            photoSettings.flashMode = flashMode
            print("CameraManager: Flash mode set to \(flashMode)")
        } else {
            print("CameraManager: Flash not available on this device")
        }
        
        // 高解像度写真を有効化
        photoSettings.isHighResolutionPhotoEnabled = true
        
        // シャッター音を無効化（CameraViewControllerで制御するため）
        photoSettings.isAutoStillImageStabilizationEnabled = false
        
        // プレビュー写真の設定
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }
        
        // セッションが実行中かチェック
        guard isSessionRunning else {
            print("Camera session is not running, cannot capture photo")
            return
        }
        
        print("Capturing photo with settings: \(photoSettings)")
        
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
            guard let currentInput = self.videoDeviceInput else { 
                print("No current video input available")
                return 
            }
            
            let currentPosition = currentInput.device.position
            let preferredPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
            
            print("Switching from \(currentPosition == .back ? "back" : "front") to \(preferredPosition == .back ? "back" : "front") camera")
            
            guard let newDevice = self.videoDevice(for: preferredPosition) else {
                print("Failed to find camera device for position: \(preferredPosition)")
                DispatchQueue.main.async {
                    let error = NSError(domain: "CameraManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "カメラの切り替えに失敗しました"])
                    self.delegate?.cameraManager(self, didFailWithError: error)
                }
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                
                self.captureSession.beginConfiguration()
                
                // 現在の入力を削除
                self.captureSession.removeInput(currentInput)
                
                // 新しい入力を追加
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.videoDeviceInput = newInput
                    print("Successfully switched to \(preferredPosition == .back ? "back" : "front") camera")
                } else {
                    // 失敗した場合は元の入力を復元
                    self.captureSession.addInput(currentInput)
                    print("Could not add new camera input, reverting to original")
                }
                
                self.captureSession.commitConfiguration()
                
            } catch {
                print("Error switching cameras: \(error)")
                // エラー時は元の入力を復元
                do {
                    self.captureSession.beginConfiguration()
                    if self.captureSession.canAddInput(currentInput) {
                        self.captureSession.addInput(currentInput)
                    }
                    self.captureSession.commitConfiguration()
                } catch {
                    print("Failed to restore original camera input: \(error)")
                }
                
                DispatchQueue.main.async {
                    self.delegate?.cameraManager(self, didFailWithError: error)
                }
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
    
    // MARK: - Image Orientation Fix
    
    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        // 画像の向きが正しい場合はそのまま返す
        if image.imageOrientation == .up {
            return image
        }
        
        // 画像を正しい向きに回転
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let correctedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return correctedImage
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("CameraManager: Photo capture will begin")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        print("CameraManager: Photo capture in progress")
        
        // iOSのAVCapturePhotoOutputが自動的にシャッター音を再生するため、
        // 手動でシャッター音を実装する必要はありません
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("CameraManager: Photo processing finished")
        
        if let error = error {
            print("CameraManager: Photo capture error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.delegate?.cameraManager(self, didFailWithError: error)
            }
            return
        }
        
        print("CameraManager: Photo captured successfully, processing image data...")
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("CameraManager: Failed to get file data representation")
            let error = NSError(domain: "CameraManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "写真データの取得に失敗しました"])
            DispatchQueue.main.async {
                self.delegate?.cameraManager(self, didFailWithError: error)
            }
            return
        }
        
        print("CameraManager: Image data size: \(imageData.count) bytes")
        
        guard let image = UIImage(data: imageData) else {
            print("CameraManager: Failed to create UIImage from data")
            let error = NSError(domain: "CameraManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "画像の作成に失敗しました"])
            DispatchQueue.main.async {
                self.delegate?.cameraManager(self, didFailWithError: error)
            }
            return
        }
        
        print("CameraManager: Image created successfully, size: \(image.size)")
        
        // 画像の向きを修正（縦向きで保存）
        let correctedImage = self.fixImageOrientation(image)
        
        DispatchQueue.main.async {
            self.delegate?.cameraManager(self, didCapturePhoto: correctedImage)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("CameraManager: Photo capture session finished")
        if let error = error {
            print("CameraManager: Photo capture session error: \(error.localizedDescription)")
        }
    }
}
