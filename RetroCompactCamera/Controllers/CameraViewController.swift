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
        setupCamera()
        setupTimer()
        updateUIForCurrentMode()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
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
        cameraManager.stopSession()
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
        
        setupConstraints()
        
        // タップジェスチャーの追加
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePreviewTap(_:)))
        previewView.addGestureRecognizer(tapGesture)
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
        
        // Grid Button (Top Left, next to flash) - iOS Camera style
        gridButton = UIButton(type: .custom)
        gridButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        gridButton.layer.cornerRadius = 22
        gridButton.layer.borderWidth = 1
        gridButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        gridButton.translatesAutoresizingMaskIntoConstraints = false
        gridButton.addTarget(self, action: #selector(gridButtonTapped), for: .touchUpInside)
        view.addSubview(gridButton)
        
        // Create custom grid icon
        let gridIconView = createGridIconView()
        gridIconView.translatesAutoresizingMaskIntoConstraints = false
        gridButton.addSubview(gridIconView)
        
        NSLayoutConstraint.activate([
            gridIconView.centerXAnchor.constraint(equalTo: gridButton.centerXAnchor),
            gridIconView.centerYAnchor.constraint(equalTo: gridButton.centerYAnchor),
            gridIconView.widthAnchor.constraint(equalToConstant: 20),
            gridIconView.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Exposure Info Label (Top Center)
        exposureInfoLabel = UILabel()
        exposureInfoLabel.text = "1/250s • f/2.8 • ISO 400"
        exposureInfoLabel.textColor = .white
        exposureInfoLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        exposureInfoLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        exposureInfoLabel.layer.cornerRadius = 12
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
            
            // Exposure Info Label
            exposureInfoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            exposureInfoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exposureInfoLabel.heightAnchor.constraint(equalToConstant: 24),
            exposureInfoLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            
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
    }
    
    private func createModeButton(title: String, index: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        button.setTitleColor(.white.withAlphaComponent(0.6), for: .normal)
        button.setTitleColor(.white, for: .selected)
        button.tag = index
        button.addTarget(self, action: #selector(modeButtonTapped(_:)), for: .touchUpInside)
        
        // iOS Camera style button design
        button.backgroundColor = .clear
        button.layer.cornerRadius = 20
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
        // Add subtle background for selected state
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        backgroundView.layer.cornerRadius = 20
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
    
    private func createCaptureButton() {
        // Premium camera style capture button (Leica-inspired)
        captureButton = UIButton(type: .custom)
        captureButton.backgroundColor = .clear
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        view.addSubview(captureButton)
        
        // Outer ring with gradient effect
        let outerRing = UIView()
        outerRing.backgroundColor = .clear
        outerRing.layer.borderWidth = 3
        outerRing.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        outerRing.layer.cornerRadius = 40 // 80/2
        outerRing.layer.shadowColor = UIColor.black.cgColor
        outerRing.layer.shadowOffset = CGSize(width: 0, height: 2)
        outerRing.layer.shadowRadius = 8
        outerRing.layer.shadowOpacity = 0.3
        outerRing.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addSubview(outerRing)
        
        // Middle ring for depth
        let middleRing = UIView()
        middleRing.backgroundColor = .clear
        middleRing.layer.borderWidth = 1
        middleRing.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        middleRing.layer.cornerRadius = 35 // 70/2
        middleRing.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addSubview(middleRing)
        
        // Inner circle with subtle gradient
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 30 // 60/2
        innerCircle.layer.shadowColor = UIColor.black.cgColor
        innerCircle.layer.shadowOffset = CGSize(width: 0, height: 1)
        innerCircle.layer.shadowRadius = 4
        innerCircle.layer.shadowOpacity = 0.2
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addSubview(innerCircle)
        
        // Center dot for premium feel
        let centerDot = UIView()
        centerDot.backgroundColor = UIColor.black.withAlphaComponent(0.1)
        centerDot.layer.cornerRadius = 8
        centerDot.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addSubview(centerDot)
        
        // Add touch feedback
        captureButton.addTarget(self, action: #selector(captureButtonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(captureButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        NSLayoutConstraint.activate([
            outerRing.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            outerRing.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            outerRing.widthAnchor.constraint(equalToConstant: 80),
            outerRing.heightAnchor.constraint(equalToConstant: 80),
            
            middleRing.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            middleRing.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            middleRing.widthAnchor.constraint(equalToConstant: 70),
            middleRing.heightAnchor.constraint(equalToConstant: 70),
            
            innerCircle.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 60),
            innerCircle.heightAnchor.constraint(equalToConstant: 60),
            
            centerDot.centerXAnchor.constraint(equalTo: captureButton.centerXAnchor),
            centerDot.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor),
            centerDot.widthAnchor.constraint(equalToConstant: 16),
            centerDot.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    private func createRecentPhotoButton() {
        recentPhotoButton = UIButton(type: .custom)
        recentPhotoButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        recentPhotoButton.layer.cornerRadius = 12
        recentPhotoButton.layer.borderWidth = 2
        recentPhotoButton.layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        recentPhotoButton.layer.shadowColor = UIColor.black.cgColor
        recentPhotoButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        recentPhotoButton.layer.shadowRadius = 6
        recentPhotoButton.layer.shadowOpacity = 0.3
        recentPhotoButton.clipsToBounds = false
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
    
    private func createGridIconView() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        // Create 3x3 grid lines using CALayer for better performance
        let lineWidth: CGFloat = 1.5
        let lineColor = UIColor.white.cgColor
        
        // Vertical lines
        for i in 1...2 {
            let line = CALayer()
            line.backgroundColor = lineColor
            line.frame = CGRect(
                x: 20 * CGFloat(i) / 3.0 - lineWidth / 2,
                y: 0,
                width: lineWidth,
                height: 20
            )
            containerView.layer.addSublayer(line)
        }
        
        // Horizontal lines
        for i in 1...2 {
            let line = CALayer()
            line.backgroundColor = lineColor
            line.frame = CGRect(
                x: 0,
                y: 20 * CGFloat(i) / 3.0 - lineWidth / 2,
                width: 20,
                height: lineWidth
            )
            containerView.layer.addSublayer(line)
        }
        
        return containerView
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
            
            
            // Mode Scroll View
            modeScrollView.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -40),
            modeScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            modeScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            modeScrollView.heightAnchor.constraint(equalToConstant: 40),
            
            // Mode Stack View
            modeStackView.topAnchor.constraint(equalTo: modeScrollView.topAnchor),
            modeStackView.bottomAnchor.constraint(equalTo: modeScrollView.bottomAnchor),
            modeStackView.leadingAnchor.constraint(equalTo: modeScrollView.leadingAnchor, constant: 50),
            modeStackView.trailingAnchor.constraint(equalTo: modeScrollView.trailingAnchor, constant: -50),
            modeStackView.heightAnchor.constraint(equalTo: modeScrollView.heightAnchor),
            
            // Capture Button (Premium camera style)
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80),
            
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
            flashOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupUI() {
        // プレビューの背景色
        previewView.backgroundColor = .black
        
        // キャプチャボタンのスタイル
        captureButton.layer.cornerRadius = captureButton.frame.width / 2
        captureButton.backgroundColor = .white
        captureButton.setTitle("", for: .normal)
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.lightGray.cgColor
        
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
        // シャッター音を再生（iOS標準音）
        AudioServicesPlaySystemSound(1108)
        
        // フラッシュ効果
        animateFlashEffect()
        
        // 写真撮影
        cameraManager.capturePhoto()
        
        // ボタンアニメーション
        animateCaptureButton()
    }
    
    @objc private func captureButtonTouchDown() {
        // Premium touch down animation with haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        UIView.animate(withDuration: 0.1, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            
            // Add subtle glow effect
            self.captureButton.layer.shadowRadius = 12
            self.captureButton.layer.shadowOpacity = 0.4
        })
    }
    
    @objc private func captureButtonTouchUp() {
        // Premium touch up animation
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [.curveEaseInOut], animations: {
            self.captureButton.transform = .identity
            
            // Remove glow effect
            self.captureButton.layer.shadowRadius = 8
            self.captureButton.layer.shadowOpacity = 0.3
        })
    }
    
    @objc private func modeButtonTapped(_ sender: UIButton) {
        // Animate mode selection with iOS-style appearance
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
            for (index, button) in self.modeButtons.enumerated() {
                let isSelected = (index == sender.tag)
                button.isSelected = isSelected
                button.setTitleColor(isSelected ? .white : .white.withAlphaComponent(0.6), for: .normal)
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
                // Draw grid lines after a short delay to ensure bounds are set
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.drawGridLines()
                }
            } else {
                self.gridOverlay.isHidden = true
                self.gridButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
                self.gridButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
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
    
    // MARK: - Animations
    
    private func animateFlashEffect() {
        flashOverlayView.alpha = 1.0
        UIView.animate(withDuration: 0.1) {
            self.flashOverlayView.alpha = 0
        }
    }
    
    private func animateCaptureButton() {
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = .identity
            }
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
            button.setTitleColor(isSelected ? .white : .white.withAlphaComponent(0.6), for: .normal)
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
        if seconds >= 1 {
            return String(format: "%.0fs", seconds)
        } else {
            let denominator = Int(1.0 / seconds)
            return "1/\(denominator)s"
        }
    }
    
    private func formatAperture(_ aperture: Float) -> String {
        return String(format: "f/%.1f", aperture)
    }
    
    private func formatISO(_ iso: Float) -> String {
        return String(format: "ISO %.0f", iso)
    }
}
