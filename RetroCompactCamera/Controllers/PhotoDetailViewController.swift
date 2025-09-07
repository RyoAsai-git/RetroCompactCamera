import UIKit
import Photos

class PhotoDetailViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    private var exifTableView: UITableView!
    private var closeButton: UIButton!
    private var bottomToolbar: UIView!
    private var shareButton: UIButton!
    private var deleteButton: UIButton!
    
    // MARK: - Properties
    
    var asset: PHAsset?
    var photos: [PHAsset] = []
    var currentIndex: Int = 0
    private let imageManager = PHImageManager.default()
    private var exifData: [(String, String)] = []
    private var isExifVisible = false
    
    // Interactive Dismissal
    private var panGesture: UIPanGestureRecognizer!
    private var backgroundView: UIView!
    private var isDismissing = false
    private let dismissThreshold: CGFloat = 0.5 // 画面の半分で閉じる判定
    
    // Photo Navigation
    private var leftSwipeGesture: UISwipeGestureRecognizer!
    private var rightSwipeGesture: UISwipeGestureRecognizer!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createUI()
        setupUI()
        setupScrollView()
        setupTableView()
        setupInteractiveDismissal()
        setupPhotoNavigation()
        loadImage()
    }
    
    // MARK: - Interface Orientation
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    // MARK: - Setup Methods
    
    private func createUI() {
        // Scroll View
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Image View
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        
        // EXIF Table View
        exifTableView = UITableView()
        exifTableView.translatesAutoresizingMaskIntoConstraints = false
        exifTableView.alpha = 0
        view.addSubview(exifTableView)
        
        // Close Button
        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)
        
        
        // Bottom Toolbar
        bottomToolbar = UIView()
        bottomToolbar.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomToolbar)
        
        // Share Button
        shareButton = UIButton(type: .system)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.tintColor = .white
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        bottomToolbar.addSubview(shareButton)
        
        // Delete Button
        deleteButton = UIButton(type: .system)
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        bottomToolbar.addSubview(deleteButton)
        
        
        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            exifTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            exifTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            exifTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            exifTableView.heightAnchor.constraint(equalToConstant: 300),
            
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            
            
            // Bottom Toolbar
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 80),
            
            // Share Button
            shareButton.centerYAnchor.constraint(equalTo: bottomToolbar.centerYAnchor),
            shareButton.leadingAnchor.constraint(equalTo: bottomToolbar.leadingAnchor, constant: 20),
            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Delete Button
            deleteButton.centerYAnchor.constraint(equalTo: bottomToolbar.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: bottomToolbar.trailingAnchor, constant: -20),
            deleteButton.widthAnchor.constraint(equalToConstant: 44),
            deleteButton.heightAnchor.constraint(equalToConstant: 44),
            
        ])
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // 閉じるボタンの設定
        closeButton.setTitle("×", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .light)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        closeButton.layer.cornerRadius = 20
        
        
        // EXIF テーブルビューを初期状態で非表示
        exifTableView.alpha = 0
    }
    
    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
    }
    
    private func setupTableView() {
        exifTableView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        exifTableView.separatorColor = .darkGray
        exifTableView.dataSource = self
        exifTableView.delegate = self
        exifTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExifCell")
        exifTableView.layer.cornerRadius = 10
        exifTableView.layer.masksToBounds = true
    }
    
    private func setupInteractiveDismissal() {
        // パンジェスチャーを追加（上下のスワイプを検知）
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delaysTouchesBegan = false
        view.addGestureRecognizer(panGesture)
        
        // 背景ビューを作成（一覧画面を表示するため）
        backgroundView = UIView()
        backgroundView.backgroundColor = .black
        backgroundView.alpha = 0
        view.insertSubview(backgroundView, at: 0)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        // 上下のスワイプのみを検知（左右は無視）
        // より厳密な条件で左右スワイプを除外
        guard abs(translation.y) > abs(translation.x) * 2 else { return }
        
        switch gesture.state {
        case .began:
            isDismissing = true
            // 一覧画面を下から上にスライドイン開始
            backgroundView.transform = CGAffineTransform(translationX: 0, y: view.bounds.height)
            backgroundView.alpha = 1.0
            
        case .changed:
            // スワイプ距離に応じてアニメーション
            let progress = min(abs(translation.y) / view.bounds.height, 1.0)
            
            // 現在の画面の透明度を変化
            view.alpha = 1.0 - (progress * 0.7)
            
            // 前の画面（一覧）を下から上にスライド
            let backgroundTranslation = max(0, view.bounds.height - (abs(translation.y) * 2))
            backgroundView.transform = CGAffineTransform(translationX: 0, y: backgroundTranslation)
            
            // 角丸の変化
            let cornerRadius = progress * 20
            backgroundView.layer.cornerRadius = cornerRadius
            
        case .ended, .cancelled:
            let progress = min(abs(translation.y) / view.bounds.height, 1.0)
            let shouldDismiss = progress > dismissThreshold || abs(velocity.y) > 500
            
            if shouldDismiss {
                // 完全に閉じる
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
                    self.view.alpha = 0
                    self.backgroundView.transform = .identity
                    self.backgroundView.layer.cornerRadius = 0
                }) { _ in
                    self.dismiss(animated: false)
                }
            } else {
                // 元の位置に戻る
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseInOut], animations: {
                    self.view.alpha = 1.0
                    self.backgroundView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
                    self.backgroundView.layer.cornerRadius = 0
                }) { _ in
                    self.isDismissing = false
                }
            }
            
        default:
            break
        }
    }
    
    private func setupPhotoNavigation() {
        // 左スワイプ（次の写真）
        leftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleLeftSwipe))
        leftSwipeGesture.direction = .left
        leftSwipeGesture.delaysTouchesBegan = false
        view.addGestureRecognizer(leftSwipeGesture)
        
        // 右スワイプ（前の写真）
        rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleRightSwipe))
        rightSwipeGesture.direction = .right
        rightSwipeGesture.delaysTouchesBegan = false
        view.addGestureRecognizer(rightSwipeGesture)
        
        // パンジェスチャーとスワイプジェスチャーの競合を解決
        panGesture.require(toFail: leftSwipeGesture)
        panGesture.require(toFail: rightSwipeGesture)
    }
    
    @objc private func handleLeftSwipe() {
        print("PhotoDetailViewController: Left swipe detected")
        // 次の写真に移動
        if currentIndex < photos.count - 1 {
            currentIndex += 1
            print("PhotoDetailViewController: Moving to next photo at index \(currentIndex)")
            loadPhoto(at: currentIndex)
        } else {
            print("PhotoDetailViewController: Already at last photo")
        }
    }
    
    @objc private func handleRightSwipe() {
        print("PhotoDetailViewController: Right swipe detected")
        // 前の写真に移動
        if currentIndex > 0 {
            currentIndex -= 1
            print("PhotoDetailViewController: Moving to previous photo at index \(currentIndex)")
            loadPhoto(at: currentIndex)
        } else {
            print("PhotoDetailViewController: Already at first photo")
        }
    }
    
    private func loadPhoto(at index: Int) {
        guard index >= 0 && index < photos.count else { return }
        
        let photo = photos[index]
        asset = photo
        
        // 画像を読み込み
        let targetSize = CGSize(width: view.frame.width * UIScreen.main.scale, 
                               height: view.frame.height * UIScreen.main.scale)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(for: photo, targetSize: targetSize, contentMode: .aspectFit, options: options) { [weak self] image, info in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 滑らかなアニメーションで画像を切り替え
                UIView.transition(with: self.imageView, duration: 0.3, options: [.transitionCrossDissolve, .allowUserInteraction], animations: {
                    self.imageView.image = image
                }, completion: nil)
                
                self.loadExifData(image: image)
            }
        }
    }
    
    private func loadImage() {
        guard let asset = asset else { return }
        
        let targetSize = CGSize(width: view.frame.width * UIScreen.main.scale, 
                               height: view.frame.height * UIScreen.main.scale)
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { [weak self] image, info in
            DispatchQueue.main.async {
                self?.imageView.image = image
                self?.loadExifData(image: image)
            }
        }
    }
    
    
    private func loadExifData(image: UIImage?) {
        guard let image = image else { return }
        
        if let exifInfo = ExifManager.readExifData(from: image) {
            exifData = ExifManager.formatExifForDisplay(exifInfo)
        } else {
            // アセットから直接メタデータを取得
            loadAssetMetadata()
        }
        
        exifTableView.reloadData()
    }
    
    private func loadAssetMetadata() {
        guard let asset = asset else { return }
        
        var metadata: [(String, String)] = []
        
        // 撮影日時
        if let creationDate = asset.creationDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            metadata.append(("撮影日時", formatter.string(from: creationDate)))
        }
        
        // 解像度
        metadata.append(("解像度", "\(asset.pixelWidth) × \(asset.pixelHeight)"))
        
        // ファイルサイズ（概算）
        let fileSize = asset.pixelWidth * asset.pixelHeight * 3 / (1024 * 1024) // 概算MB
        metadata.append(("ファイルサイズ", "\(fileSize) MB (概算)"))
        
        // 位置情報
        if let location = asset.location {
            let lat = String(format: "%.6f", location.coordinate.latitude)
            let lon = String(format: "%.6f", location.coordinate.longitude)
            metadata.append(("位置情報", "\(lat), \(lon)"))
        }
        
        exifData = metadata
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    
    @objc private func shareButtonTapped() {
        guard let asset = asset else { return }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        
        imageManager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { [weak self] image, _ in
            guard let image = image else { return }
            
            DispatchQueue.main.async {
                let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                self?.present(activityVC, animated: true)
            }
        }
    }
    
    @objc private func deleteButtonTapped() {
        guard let asset = asset else { return }
        
        let alert = UIAlertController(title: "写真を削除", message: "この写真を削除しますか？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "削除", style: .destructive) { [weak self] _ in
            self?.deletePhoto()
        })
        present(alert, animated: true)
    }
    
    private func deletePhoto() {
        guard let asset = asset else { return }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.dismiss(animated: true)
                } else {
                    print("Failed to delete photo: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}

// MARK: - UIScrollViewDelegate

extension PhotoDetailViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
    }
}

// MARK: - UITableViewDataSource

extension PhotoDetailViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return exifData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExifCell", for: indexPath)
        
        let (key, value) = exifData[indexPath.row]
        
        cell.textLabel?.text = key
        cell.detailTextLabel?.text = value
        cell.backgroundColor = .clear
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.textColor = .lightGray
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12)
        cell.selectionStyle = .none
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PhotoDetailViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}

