import UIKit
import AVFoundation
import Photos
import AudioToolbox
import CoreMedia

class CameraViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private var previewView: UIView!
    private var captureButton: UIButton!
    private var modeScrollView: UIScrollView!
    private var modeStackView: UIStackView!
    private var flashButton: UIButton!
    private var timerButton: UIButton!
    private var focusFrameView: UIView!
    private var flashOverlayView: UIView!
    private var recentPhotoButton: UIButton!
    private var cameraSwitchButton: UIButton!
    
    // Top controls
    private var topControlsStackView: UIStackView!
    private var exposureInfoLabel: UILabel!
    private var gridButton: UIButton!
    private var gridOverlay: UIView!
    
    // Mode buttons
    private var modeButtons: [UIButton] = []
    private var modeButtonBackgrounds: [UIView] = []
    private let modeNames = ["Early Digital", "Compact Digital", "Superzoom"]
    
    // Exposure settings
    private var isGridVisible = false
    
    // Zoom settings
    private var zoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 10.0
    private var minZoomFactor: CGFloat = 1.0
    private var zoomButtons: [UIButton] = []
    private var zoomButtonBackgrounds: [UIView] = []
    private var zoomStackView: UIStackView!
    
    // MARK: - Properties
    
    private let cameraManager = CameraManager()
    private let imageProcessor = ImageProcessor()
    private var currentMode: EraMode = .earlyDigital
    private var dateTimeTimer: Timer?
    
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    // Real-time filter properties
    private var ciContext: CIContext!
    private var metalDevice: MTLDevice!
    private var isPreviewFilterEnabled = true
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createUI()
        setupUI()
        setupTimer()
        updateUIForCurrentMode()
        
        // カメラの設定はviewWillAppearで行う
        cameraManager.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // カメラセッションの初期化と開始
        setupCamera()
        
        cameraManager.checkCameraAuthorization { [weak self] granted in
            print("Camera authorization granted: \(granted)")
            if granted {
                print("Starting camera session...")
                self?.cameraManager.startSession()
            } else {
                print("Camera access denied, showing alert")
                self?.showCameraAccessAlert()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // セッションを停止してリソースを解放
        cameraManager.stopSession()
        
        // タイマーを停止
        dateTimeTimer?.invalidate()
        dateTimeTimer = nil
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
    }
    
    deinit {
        dateTimeTimer?.invalidate()
    }
    
    // MARK: - Setup Methods
    
    private func createUI() {
        view.backgroundColor = .black
        
        // Setup Metal for real-time filters
        setupMetal()
        
        // Preview View - Full screen
        previewView = UIView()
        previewView.backgroundColor = .black
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        
        // Top Controls Stack View
        createTopControls()
        
        // Mode Selection (Horizontal scroll like iOS camera)
        createModeSelection()
        
        // Capture Button (iOS style)
        createCaptureButton()
        
        // Recent Photo Button (Left bottom)
        createRecentPhotoButton()
        
        // Camera Switch Button (Right bottom)
        createCameraSwitchButton()
        
        // Focus Frame View
        focusFrameView = UIView()
        focusFrameView.layer.borderWidth = 2
        focusFrameView.layer.borderColor = UIColor.systemYellow.cgColor
        focusFrameView.backgroundColor = .clear
        focusFrameView.isHidden = true
        focusFrameView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(focusFrameView)
        
        // Flash Overlay View
        flashOverlayView = UIView()
        flashOverlayView.backgroundColor = .white
        flashOverlayView.alpha = 0
        flashOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flashOverlayView)
        
        // Grid Overlay
        createGridOverlay()
        
        // Zoom Controls
        createZoomControls()
        
        setupConstraints()
        
        // タップジェスチャーの追加
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePreviewTap(_:)))
        previewView.addGestureRecognizer(tapGesture)
        
        // ピンチジェスチャーの追加
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        previewView.addGestureRecognizer(pinchGesture)
    }
    
    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        if let device = metalDevice {
            ciContext = CIContext(mtlDevice: device)
        } else {
            ciContext = CIContext()
        }
    }
    
    private func createTopControls() {
        // Flash Button (Top Left) - Premium design
        flashButton = UIButton(type: .custom)
        flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashButton.tintColor = .systemYellow
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        flashButton.layer.cornerRadius = 22
        flashButton.layer.borderWidth = 1
        flashButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        flashButton.layer.shadowColor = UIColor.black.cgColor
        flashButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        flashButton.layer.shadowRadius = 4
        flashButton.layer.shadowOpacity = 0.2
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        view.addSubview(flashButton)
        
        // Grid Button (Top Left, next to flash) - iOS Camera style with custom grid icon
        gridButton = UIButton(type: .custom)
        gridButton.setImage(createGridIcon(), for: .normal)
        gridButton.tintColor = .white
        gridButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        gridButton.layer.cornerRadius = 22
        gridButton.layer.borderWidth = 1
        gridButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        gridButton.layer.shadowColor = UIColor.black.cgColor
        gridButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        gridButton.layer.shadowRadius = 4
        gridButton.layer.shadowOpacity = 0.2
        gridButton.translatesAutoresizingMaskIntoConstraints = false
        gridButton.addTarget(self, action: #selector(gridButtonTapped), for: .touchUpInside)
        view.addSubview(gridButton)
        
        // Exposure Info Label (Top Center)
        exposureInfoLabel = UILabel()
        exposureInfoLabel.text = "1/250s • f/2.8 • ISO 400"
        exposureInfoLabel.textColor = .white
        exposureInfoLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        exposureInfoLabel.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        exposureInfoLabel.layer.cornerRadius = 8
        exposureInfoLabel.layer.masksToBounds = true
        exposureInfoLabel.textAlignment = .center
        exposureInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(exposureInfoLabel)
        
        // Timer Button (Top Right) - Premium design
        timerButton = UIButton(type: .custom)
        timerButton.setImage(UIImage(systemName: "timer"), for: .normal)
        timerButton.tintColor = .white
        timerButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        timerButton.layer.cornerRadius = 22
        timerButton.layer.borderWidth = 1
        timerButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        timerButton.layer.shadowColor = UIColor.black.cgColor
        timerButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        timerButton.layer.shadowRadius = 4
        timerButton.layer.shadowOpacity = 0.2
        timerButton.translatesAutoresizingMaskIntoConstraints = false
        timerButton.addTarget(self, action: #selector(timerButtonTapped), for: .touchUpInside)
        view.addSubview(timerButton)
        
        // Set constraints
        NSLayoutConstraint.activate([
            // Flash Button
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Grid Button
            gridButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            gridButton.leadingAnchor.constraint(equalTo: flashButton.trailingAnchor, constant: 12),
            gridButton.widthAnchor.constraint(equalToConstant: 40),
            gridButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Exposure Info Label constraints will be set after modeScrollView is created
            
            // Timer Button
            timerButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            timerButton.widthAnchor.constraint(equalToConstant: 40),
            timerButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func createModeSelection() {
        // Mode Scroll View (like iOS camera)
        modeScrollView = UIScrollView()
        modeScrollView.showsHorizontalScrollIndicator = false
        modeScrollView.decelerationRate = .fast
        modeScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeScrollView)
        
        modeStackView = UIStackView()
        modeStackView.axis = .horizontal
        modeStackView.spacing = 0
        modeStackView.alignment = .center
        modeStackView.translatesAutoresizingMaskIntoConstraints = false
        modeScrollView.addSubview(modeStackView)
        
        // Create mode buttons with iOS-style design
        for (index, modeName) in modeNames.enumerated() {
            let button = createModeButton(title: modeName, index: index)
            modeButtons.append(button)
            modeStackView.addArrangedSubview(button)
        }
        
        // Set exposure info label constraints after modeScrollView is created
        NSLayoutConstraint.activate([
            exposureInfoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            exposureInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exposureInfoLabel.heightAnchor.constraint(equalToConstant: 32),
            exposureInfoLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }
    
    private func createModeButton(title: String, index: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium) // iOS純正カメラ風
        button.setTitleColor(.white.withAlphaComponent(0.6), for: .normal)
        button.setTitleColor(.systemYellow, for: .selected) // 選択時は黄色
        button.tag = index
        button.addTarget(self, action: #selector(modeButtonTapped(_:)), for: .touchUpInside)
        
        // iOS純正カメラ風のスタイル
        button.backgroundColor = .clear
        button.layer.cornerRadius = 0
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        // 選択状態の背景（iOS純正カメラ風）
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        backgroundView.layer.cornerRadius = 0
        backgroundView.isHidden = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        button.insertSubview(backgroundView, at: 0)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: button.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        // Store background view reference in array
        modeButtonBackgrounds.append(backgroundView)
        
        if index == 0 {
            button.isSelected = true
            backgroundView.isHidden = false
        }
        
        return button
    }
    
    private func createGridIcon() -> UIImage? {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            cgContext.setStrokeColor(UIColor.white.cgColor)
            cgContext.setLineWidth(1.5)
            
            // 3x3グリッドを描画
            let spacing = size.width / 3
            
            // 縦線
            for i in 1...2 {
                let x = spacing * CGFloat(i)
                cgContext.move(to: CGPoint(x: x, y: 0))
                cgContext.addLine(to: CGPoint(x: x, y: size.height))
            }
            
            // 横線
            for i in 1...2 {
                let y = spacing * CGFloat(i)
                cgContext.move(to: CGPoint(x: 0, y: y))
                cgContext.addLine(to: CGPoint(x: size.width, y: y))
            }
            
            cgContext.strokePath()
        }
    }
    
    private func createCaptureButton() {
        // Perfect iOS camera style capture button - completely round
        captureButton = UIButton(type: .custom)
        captureButton.backgroundColor = .clear
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        view.addSubview(captureButton)
        
        // Outer ring - perfect circle with white border
        let outerRing = UIView()
        outerRing.backgroundColor = .clear
        outerRing.layer.borderWidth = 4
        outerRing.layer.borderColor = UIColor.white.cgColor
        outerRing.layer.cornerRadius = 37.5 // 75/2 - perfect circle
        outerRing.layer.shadowColor = UIColor.black.cgColor
        outerRing.layer.shadowOffset = CGSize(width: 0, height: 2)
        outerRing.layer.shadowRadius = 6
        outerRing.layer.shadowOpacity = 0.2
        outerRing.translatesAutoresizingMaskIntoConstraints = false
        outerRing.isUserInteractionEnabled = false // タッチイベントを無効化
        captureButton.addSubview(outerRing)
        
        // Inner circle - perfect solid white circle
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 30 // 60/2 - perfect circle
        innerCircle.layer.shadowColor = UIColor.black.cgColor
        innerCircle.layer.shadowOffset = CGSize(width: 0, height: 1)
        innerCircle.layer.shadowRadius = 3
        innerCircle.layer.shadowOpacity = 0.1
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        innerCircle.isUserInteractionEnabled = false // タッチイベントを無効化
        captureButton.addSubview(innerCircle)
        
        // Add touch feedback
        captureButton.addTarget(self, action: #selector(captureButtonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(captureButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        NSLayoutConstraint.activate([
            outerRing.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            outerRing.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            outerRing.widthAnchor.constraint(equalToConstant: 75),
            outerRing.heightAnchor.constraint(equalToConstant: 75),
            
            innerCircle.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 60),
            innerCircle.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    private func createRecentPhotoButton() {
        recentPhotoButton = UIButton(type: .custom)
        recentPhotoButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        recentPhotoButton.layer.cornerRadius = 12
        recentPhotoButton.layer.borderWidth = 0 // 枠線を削除
        recentPhotoButton.layer.shadowColor = UIColor.black.cgColor
        recentPhotoButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        recentPhotoButton.layer.shadowRadius = 6
        recentPhotoButton.layer.shadowOpacity = 0.3
        recentPhotoButton.clipsToBounds = true // 角丸を適用
        recentPhotoButton.translatesAutoresizingMaskIntoConstraints = false
        recentPhotoButton.addTarget(self, action: #selector(recentPhotoButtonTapped), for: .touchUpInside)
        view.addSubview(recentPhotoButton)
        
        // Set content mode for proper image display
        recentPhotoButton.imageView?.contentMode = .scaleAspectFill
        recentPhotoButton.imageView?.clipsToBounds = true
        
        // Add placeholder icon when no image is available
        recentPhotoButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        recentPhotoButton.tintColor = .white.withAlphaComponent(0.7)
        
        // Load most recent photo thumbnail
        loadRecentPhoto()
    }
    
    private func createCameraSwitchButton() {
        cameraSwitchButton = UIButton(type: .custom)
        cameraSwitchButton.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera"), for: .normal)
        cameraSwitchButton.tintColor = .white
        cameraSwitchButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        cameraSwitchButton.layer.cornerRadius = 25
        cameraSwitchButton.layer.borderWidth = 1
        cameraSwitchButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        cameraSwitchButton.layer.shadowColor = UIColor.black.cgColor
        cameraSwitchButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        cameraSwitchButton.layer.shadowRadius = 6
        cameraSwitchButton.layer.shadowOpacity = 0.3
        cameraSwitchButton.translatesAutoresizingMaskIntoConstraints = false
        cameraSwitchButton.addTarget(self, action: #selector(cameraSwitchButtonTapped), for: .touchUpInside)
        view.addSubview(cameraSwitchButton)
    }
    
    
    private func createGridOverlay() {
        gridOverlay = UIView()
        gridOverlay.backgroundColor = .clear
        gridOverlay.isHidden = true
        gridOverlay.translatesAutoresizingMaskIntoConstraints = false
        previewView.addSubview(gridOverlay)
        
        NSLayoutConstraint.activate([
            gridOverlay.topAnchor.constraint(equalTo: previewView.topAnchor),
            gridOverlay.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            gridOverlay.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            gridOverlay.bottomAnchor.constraint(equalTo: previewView.bottomAnchor)
        ])
    }
    
    private func createZoomControls() {
        // Zoom Stack View (iOS Camera style - number buttons)
        zoomStackView = UIStackView()
        zoomStackView.axis = .horizontal
        zoomStackView.spacing = 8
        zoomStackView.alignment = .center
        zoomStackView.distribution = .fillEqually
        zoomStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(zoomStackView)
        
        // Create zoom buttons (0.5x, 1x, 2x, 3x) - iOS純正カメラ風
        let zoomLevels: [CGFloat] = [0.5, 1.0, 2.0, 3.0]
        
        for (index, level) in zoomLevels.enumerated() {
            let button = createZoomButton(level: level, index: index)
            zoomButtons.append(button)
            zoomStackView.addArrangedSubview(button)
        }
        
        // Set zoom stack view constraints after captureButton is created
        NSLayoutConstraint.activate([
            zoomStackView.bottomAnchor.constraint(equalTo: modeScrollView.topAnchor, constant: -10),
            zoomStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            zoomStackView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func createZoomButton(level: CGFloat, index: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(level == 1.0 ? "1" : String(format: "%.1f", level), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium) // iOS純正カメラ風
        button.setTitleColor(.white.withAlphaComponent(0.6), for: .normal)
        button.setTitleColor(.systemYellow, for: .selected) // 選択時は黄色
        button.tag = index
        button.addTarget(self, action: #selector(zoomButtonTapped(_:)), for: .touchUpInside)
        
        // iOS純正カメラ風のボタンデザイン
        button.backgroundColor = .clear
        button.layer.cornerRadius = 0
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        // 選択状態の背景（iOS純正カメラ風）
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        backgroundView.layer.cornerRadius = 0
        backgroundView.isHidden = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        button.insertSubview(backgroundView, at: 0)
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: button.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        
        // Store background view reference in array
        zoomButtonBackgrounds.append(backgroundView)
        
        if level == 1.0 {
            button.isSelected = true
            backgroundView.isHidden = false
        }
        
        return button
    }
    
    private func drawGridLines() {
        // Remove existing sublayers
        gridOverlay.layer.sublayers?.removeAll()
        
        let lineWidth: CGFloat = 0.5
        let lineColor = UIColor.white.withAlphaComponent(0.5).cgColor
        
        let bounds = gridOverlay.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        // Vertical lines
        for i in 1...2 {
            let line = CALayer()
            line.backgroundColor = lineColor
            line.frame = CGRect(
                x: bounds.width * CGFloat(i) / 3.0 - lineWidth / 2,
                y: 0,
                width: lineWidth,
                height: bounds.height
            )
            gridOverlay.layer.addSublayer(line)
        }
        
        // Horizontal lines
        for i in 1...2 {
            let line = CALayer()
            line.backgroundColor = lineColor
            line.frame = CGRect(
                x: 0,
                y: bounds.height * CGFloat(i) / 3.0 - lineWidth / 2,
                width: bounds.width,
                height: lineWidth
            )
            gridOverlay.layer.addSublayer(line)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Preview View - Full screen
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            
            // Mode Scroll View (above capture button, iOS camera style)
            modeScrollView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -20),
            modeScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            modeScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            modeScrollView.heightAnchor.constraint(equalToConstant: 50),
            
            // Mode Stack View
            modeStackView.topAnchor.constraint(equalTo: modeScrollView.topAnchor),
            modeStackView.bottomAnchor.constraint(equalTo: modeScrollView.bottomAnchor),
            modeStackView.leadingAnchor.constraint(equalTo: modeScrollView.leadingAnchor, constant: 50),
            modeStackView.trailingAnchor.constraint(equalTo: modeScrollView.trailingAnchor, constant: -50),
            modeStackView.heightAnchor.constraint(equalTo: modeScrollView.heightAnchor),
            
            // Capture Button (iOS default camera style)
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            captureButton.widthAnchor.constraint(equalToConstant: 75),
            captureButton.heightAnchor.constraint(equalToConstant: 75),
            
            // Recent Photo Button (Left bottom - iOS camera style)
            recentPhotoButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            recentPhotoButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            recentPhotoButton.widthAnchor.constraint(equalToConstant: 45),
            recentPhotoButton.heightAnchor.constraint(equalToConstant: 45),
            
            // Camera Switch Button (Right bottom)
            cameraSwitchButton.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            cameraSwitchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            cameraSwitchButton.widthAnchor.constraint(equalToConstant: 50),
            cameraSwitchButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Focus Frame View
            focusFrameView.centerXAnchor.constraint(equalTo: previewView.centerXAnchor),
            focusFrameView.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            focusFrameView.widthAnchor.constraint(equalToConstant: 80),
            focusFrameView.heightAnchor.constraint(equalToConstant: 80),
            
            // Flash Overlay View
            flashOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            flashOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flashOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            flashOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Zoom Stack View constraints will be set after captureButton is created
        ])
    }
    
    private func setupUI() {
        // プレビューの背景色
        previewView.backgroundColor = .black
        
        // キャプチャボタンのスタイルはcreateCaptureButton()で設定済み
        
        // モードボタンの初期設定
        updateModeSelection()
        
        // フォーカスフレームの設定
        focusFrameView.layer.borderWidth = 2
        focusFrameView.layer.borderColor = UIColor.green.cgColor
        focusFrameView.backgroundColor = .clear
        focusFrameView.isHidden = true
        
        // フラッシュオーバーレイの設定
        flashOverlayView.backgroundColor = .white
        flashOverlayView.alpha = 0
        
        // 最新写真の読み込み
        loadRecentPhoto()
        
        // タップジェスチャーの追加
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePreviewTap(_:)))
        previewView.addGestureRecognizer(tapGesture)
    }
    
    private func setupCamera() {
        cameraManager.delegate = self
        
        // プレビューレイヤーの設定
        previewLayer = cameraManager.previewLayer
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
    }
    
    private func setupTimer() {
        dateTimeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDateTime()
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUIForCurrentMode() {
        // Update mode-specific UI elements
        updatePreviewLayerForMode()
        
        // Update mode button selection
        updateModeSelection()
        
        // Apply real-time filter effect
        applyRealtimeFilter()
    }
    
    private func updateDateTime() {
        // DateTime display removed in new UI design
        // This method is kept for compatibility but does nothing
    }
    
    private func startRecordingAnimation() {
        // Recording indicator removed in new UI design
        // This method is kept for compatibility but does nothing
    }
    
    private func stopRecordingAnimation() {
        // Recording indicator removed in new UI design
        // This method is kept for compatibility but does nothing
    }
    
    // MARK: - Actions
    
    @objc private func captureButtonTapped() {
        print("CameraViewController: Capture button tapped - SUCCESS!")
        print("CameraViewController: Button frame: \(captureButton.frame)")
        print("CameraViewController: Button bounds: \(captureButton.bounds)")
        
        // カメラセッションが実行中かチェック
        guard cameraManager.isSessionRunning else {
            print("CameraViewController: Camera session is not running, cannot capture photo")
            let alert = UIAlertController(
                title: "カメラエラー",
                message: "カメラが起動していません。しばらく待ってから再度お試しください。",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // シャッター音を再生（iOS標準音）
        AudioServicesPlaySystemSound(1108)
        
        // フラッシュ効果
        animateFlashEffect()
        
        // 写真撮影
        print("CameraViewController: Calling cameraManager.capturePhoto()")
        cameraManager.capturePhoto()
        
        // ボタンアニメーション
        animateCaptureButton()
    }
    
    @objc private func captureButtonTouchDown() {
        print("CameraViewController: Capture button touch down detected")
        // iOS camera style touch down animation
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 内円の縮小アニメーション
        UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        })
    }
    
    @objc private func captureButtonTouchUp() {
        // iOS camera style touch up animation
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            self.captureButton.transform = .identity
        })
    }
    
    @objc private func modeButtonTapped(_ sender: UIButton) {
        // Animate mode selection with iOS-style appearance
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            for (index, button) in self.modeButtons.enumerated() {
                let isSelected = (index == sender.tag)
                button.isSelected = isSelected
                button.setTitleColor(isSelected ? .systemYellow : .white.withAlphaComponent(0.6), for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: isSelected ? .semibold : .medium)
                
                // Animate background view using array reference
                if index < self.modeButtonBackgrounds.count {
                    let backgroundView = self.modeButtonBackgrounds[index]
                    backgroundView.isHidden = !isSelected
                    backgroundView.alpha = isSelected ? 1.0 : 0.0
                }
                
                // Scale animation for selected button
                button.transform = isSelected ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
            }
        }) { _ in
            // Reset transform after animation
            for button in self.modeButtons {
                if !button.isSelected {
                    button.transform = .identity
                }
            }
        }
        
        // Update current mode
        currentMode = EraMode.allCases[sender.tag]
        updateUIForCurrentMode()
        
        // Apply real-time filter
        applyRealtimeFilter()
    }
    
    @objc private func flashButtonTapped() {
        // Toggle flash state with smooth animation
        let currentImage = flashButton.image(for: .normal)
        let isFlashOff = currentImage == UIImage(systemName: "bolt.slash.fill")
        
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            self.flashButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
                self.flashButton.transform = .identity
            })
        }
        
        if isFlashOff {
            flashButton.setImage(UIImage(systemName: "bolt.fill"), for: .normal)
            flashButton.tintColor = .systemYellow
            flashButton.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.2)
        } else {
            flashButton.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
            flashButton.tintColor = .systemYellow
            flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        }
    }
    
    @objc private func gridButtonTapped() {
        isGridVisible.toggle()
        
        UIView.animate(withDuration: 0.2, animations: {
            if self.isGridVisible {
                self.gridOverlay.isHidden = false
                self.gridButton.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
                self.gridButton.layer.borderColor = UIColor.systemYellow.cgColor
                self.gridButton.tintColor = .systemYellow
                // Draw grid lines after a short delay to ensure bounds are set
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.drawGridLines()
                }
            } else {
                self.gridOverlay.isHidden = true
                self.gridButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
                self.gridButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
                self.gridButton.tintColor = .white
            }
        })
    }
    
    @objc private func timerButtonTapped() {
        // Timer functionality (placeholder)
        print("Timer button tapped")
    }
    
    @objc private func recentPhotoButtonTapped() {
        let galleryVC = GalleryViewController()
        galleryVC.modalPresentationStyle = .fullScreen
        present(galleryVC, animated: true)
    }
    
    @objc private func cameraSwitchButtonTapped() {
        // Camera switch functionality
        cameraManager.switchCamera()
        
        // Premium animation for button feedback
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            self.cameraSwitchButton.transform = CGAffineTransform(rotationAngle: .pi)
            self.cameraSwitchButton.transform = self.cameraSwitchButton.transform.scaledBy(x: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
                self.cameraSwitchButton.transform = .identity
            })
        }
    }
    
    @objc private func handlePreviewTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: previewView)
        let convertedPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
        
        // フォーカスフレームを表示
        showFocusFrame(at: location)
        
        // フォーカスと露出を設定
        cameraManager.focusAndExpose(at: convertedPoint)
    }
    
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let device = cameraManager.getCurrentDevice() else { return }
        
        switch gesture.state {
        case .began:
            // ズーム開始時の処理
            break
        case .changed:
            // ズーム倍率を更新
            let newZoomFactor = zoomFactor * gesture.scale
            let clampedZoomFactor = max(minZoomFactor, min(newZoomFactor, maxZoomFactor))
            
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoomFactor
                device.unlockForConfiguration()
                
                zoomFactor = clampedZoomFactor
                updateZoomButtonsForCurrentFactor()
            } catch {
                print("Failed to set zoom factor: \(error)")
            }
            
            gesture.scale = 1.0
        case .ended, .cancelled:
            // ズーム終了時の処理
            break
        default:
            break
        }
    }
    
    private func updateZoomButtonsForCurrentFactor() {
        let zoomLevels: [CGFloat] = [0.5, 1.0, 2.0, 3.0]
        
        // 現在のズーム倍率に最も近いボタンを選択
        var closestIndex = 0
        var minDifference = abs(zoomFactor - zoomLevels[0])
        
        for (index, level) in zoomLevels.enumerated() {
            let difference = abs(zoomFactor - level)
            if difference < minDifference {
                minDifference = difference
                closestIndex = index
            }
        }
        
        // 最も近いボタンを選択
        if closestIndex < zoomButtons.count {
            updateZoomButtonSelection(selectedButton: zoomButtons[closestIndex])
        }
    }
    
    @objc private func zoomButtonTapped(_ sender: UIButton) {
        let zoomLevels: [CGFloat] = [0.5, 1.0, 2.0, 3.0]
        let selectedLevel = zoomLevels[sender.tag]
        
        // ズームを設定
        setZoomLevel(selectedLevel)
        
        // UIを更新
        updateZoomButtonSelection(selectedButton: sender)
    }
    
    private func setZoomLevel(_ level: CGFloat) {
        guard let device = cameraManager.getCurrentDevice() else { return }
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = level
            device.unlockForConfiguration()
            
            zoomFactor = level
            print("Zoom set to: \(level)x")
        } catch {
            print("Failed to set zoom factor: \(error)")
        }
    }
    
    private func updateZoomButtonSelection(selectedButton: UIButton) {
        // 全てのボタンの選択状態をリセット
        for (index, button) in zoomButtons.enumerated() {
            button.isSelected = false
            if index < zoomButtonBackgrounds.count {
                let backgroundView = zoomButtonBackgrounds[index]
                backgroundView.isHidden = true
            }
        }
        
        // 選択されたボタンをハイライト
        selectedButton.isSelected = true
        if let selectedIndex = zoomButtons.firstIndex(of: selectedButton),
           selectedIndex < zoomButtonBackgrounds.count {
            let backgroundView = zoomButtonBackgrounds[selectedIndex]
            backgroundView.isHidden = false
        }
    }
    
    // MARK: - Animations
    
    private func animateFlashEffect() {
        flashOverlayView.alpha = 1.0
        UIView.animate(withDuration: 0.1) {
            self.flashOverlayView.alpha = 0
        }
    }
    
    private func animateCaptureButton() {
        // iOS camera style capture animation - 内円の点滅効果
        UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
                self.captureButton.transform = .identity
            })
        }
    }
    
    private func showFocusFrame(at point: CGPoint) {
        focusFrameView.center = point
        focusFrameView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusFrameView.alpha = 1.0
        focusFrameView.isHidden = false
        
        UIView.animate(withDuration: 0.3, animations: {
            self.focusFrameView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 0.5, options: [], animations: {
                self.focusFrameView.alpha = 0
            }) { _ in
                self.focusFrameView.isHidden = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showCameraAccessAlert() {
        let alert = UIAlertController(
            title: "カメラアクセス",
            message: "カメラを使用するには設定でアクセスを許可してください。",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "設定", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        
        present(alert, animated: true)
    }
    
    
    private func showSaveSuccessMessage() {
        let alert = UIAlertController(title: "保存完了", message: "写真がフォトライブラリに保存されました。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showSaveErrorMessage() {
        let alert = UIAlertController(title: "保存エラー", message: "写真の保存に失敗しました。", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - CameraManagerDelegate

extension CameraViewController: CameraManagerDelegate {
    
    func cameraManager(_ manager: CameraManager, didCapturePhoto image: UIImage) {
        // 年代別エフェクトを適用
        if let processedImage = imageProcessor.processImage(image, with: currentMode) {
            // EXIF情報付きで保存
            ExifManager.saveImageWithExif(processedImage, mode: currentMode) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.showSaveSuccessMessage()
                        // Update recent photo button with new image
                        self?.recentPhotoButton.setImage(processedImage, for: .normal)
                        self?.recentPhotoButton.tintColor = .clear
                    } else {
                        self?.showSaveErrorMessage()
                    }
                }
            }
        } else {
            // EXIF情報付きで保存
            ExifManager.saveImageWithExif(image, mode: currentMode) { [weak self] success, error in
                DispatchQueue.main.async {
                    if success {
                        self?.showSaveSuccessMessage()
                        // Update recent photo button with new image
                        self?.recentPhotoButton.setImage(image, for: .normal)
                        self?.recentPhotoButton.tintColor = .clear
                    } else {
                        self?.showSaveErrorMessage()
                    }
                }
            }
        }
    }
    
    func cameraManager(_ manager: CameraManager, didFailWithError error: Error) {
        let alert = UIAlertController(title: "エラー", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func cameraManagerDidStartRunning(_ manager: CameraManager) {
        // カメラ開始時の処理
        print("CameraViewController: Camera started running")
        DispatchQueue.main.async {
            // プレビューレイヤーのフレームを再設定
            self.previewLayer.frame = self.previewView.bounds
            print("CameraViewController: Preview layer frame set to \(self.previewView.bounds)")
            
            // Draw grid lines if visible
            if self.isGridVisible {
                self.drawGridLines()
            }
            
            // Start updating exposure info
            self.startExposureInfoUpdates()
        }
    }
    
    func cameraManagerDidStopRunning(_ manager: CameraManager) {
        // カメラ停止時の処理
        print("CameraViewController: Camera stopped running")
        
        DispatchQueue.main.async {
            // 露出情報の更新を停止
            self.dateTimeTimer?.invalidate()
            self.dateTimeTimer = nil
        }
    }
}

// MARK: - Additional Helper Methods

extension CameraViewController {
    
    private func loadRecentPhoto() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            if let asset = assets.firstObject {
                let imageManager = PHImageManager.default()
                let targetSize = CGSize(width: 50, height: 50)
                
                imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil) { [weak self] image, _ in
                    DispatchQueue.main.async {
                        if let image = image {
                            self?.recentPhotoButton.setImage(image, for: .normal)
                            self?.recentPhotoButton.tintColor = .clear
                        }
                    }
                }
            }
        }
    }
    
    private func applyRealtimeFilter() {
        // This would integrate with AVCaptureVideoDataOutput for real-time filtering
        // For now, we'll update the preview layer appearance
        updatePreviewLayerForMode()
    }
    
    private func updatePreviewLayerForMode() {
        guard previewLayer != nil else { return }
        
        // Apply visual effects to preview layer based on current mode
        switch currentMode {
        case .earlyDigital:
            // Lower quality, more noise effect
            previewLayer.opacity = 0.9
        case .compactDigital:
            // Balanced quality
            previewLayer.opacity = 1.0
        case .superzoom:
            // Higher quality but with motion blur simulation
            previewLayer.opacity = 0.95
        }
    }
    
    private func updateModeSelection() {
        // Update mode button selection with iOS-style appearance
        for (index, button) in modeButtons.enumerated() {
            let isSelected = (EraMode.allCases[index] == currentMode)
            button.isSelected = isSelected
            button.setTitleColor(isSelected ? .systemYellow : .white.withAlphaComponent(0.6), for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: isSelected ? .semibold : .medium)
            
            // Update background view using array reference
            if index < modeButtonBackgrounds.count {
                let backgroundView = modeButtonBackgrounds[index]
                backgroundView.isHidden = !isSelected
                backgroundView.alpha = isSelected ? 1.0 : 0.0
            }
        }
    }
    
    // MARK: - Exposure Info Updates
    
    private func startExposureInfoUpdates() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateExposureInfo()
        }
    }
    
    private func updateExposureInfo() {
        guard let device = cameraManager.getCurrentDevice() else {
            return
        }
        
        // NaN/Inf チェックを追加
        let shutterSpeed = formatShutterSpeed(device.exposureDuration)
        let aperture = formatAperture(device.lensAperture)
        let iso = formatISO(device.iso)
        
        let exposureText = "\(shutterSpeed) • \(aperture) • \(iso)"
        
        DispatchQueue.main.async {
            self.exposureInfoLabel.text = exposureText
        }
    }
    
    private func formatShutterSpeed(_ duration: CMTime) -> String {
        let seconds = CMTimeGetSeconds(duration)
        
        // NaN/Inf チェック
        guard seconds.isFinite && seconds > 0 else {
            return "1/60s" // デフォルト値
        }
        
        if seconds >= 1 {
            return String(format: "%.0fs", seconds)
        } else {
            let denominator = Int(1.0 / seconds)
            // 分母が有効な範囲内かチェック
            if denominator > 0 && denominator < 10000 {
                return "1/\(denominator)s"
            } else {
                return "1/60s" // デフォルト値
            }
        }
    }
    
    private func formatAperture(_ aperture: Float) -> String {
        // NaN/Inf チェック
        guard aperture.isFinite && aperture > 0 else {
            return "f/2.8" // デフォルト値
        }
        
        return String(format: "f/%.1f", aperture)
    }
    
    private func formatISO(_ iso: Float) -> String {
        // NaN/Inf チェック
        guard iso.isFinite && iso > 0 else {
            return "ISO 400" // デフォルト値
        }
        
        return String(format: "ISO %.0f", iso)
    }
}
