import UIKit
import Photos

class GalleryViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private var collectionView: UICollectionView!
    private var pageViewController: UIPageViewController!
    private var topToolbar: UIView!
    private var bottomToolbar: UIView!
    private var backButton: UIButton!
    private var titleLabel: UILabel!
    private var allPhotosButton: UIButton!
    
    // MARK: - Properties
    
    private var photos: [PHAsset] = []
    private let imageManager = PHImageManager.default()
    private let cellIdentifier = "PhotoCell"
    private var currentIndex: Int = 0
    private var isFullscreen: Bool = false
    private var fullscreenViewControllers: [FullscreenPhotoViewController] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSwipeGestures()
        loadPhotos()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupInitialState()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = .black
        
        createTopToolbar()
        createBottomToolbar()
        createCollectionView()
        createPageViewController()
        setupConstraints()
    }
    
    private func createTopToolbar() {
        topToolbar = UIView()
        topToolbar.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        topToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topToolbar)
        
        // Back Button
        backButton = UIButton(type: .system)
        backButton.setTitle("完了", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        topToolbar.addSubview(backButton)
        
        // Title Label
        titleLabel = UILabel()
        titleLabel.text = "最近撮った写真"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topToolbar.addSubview(titleLabel)
        
        // All Photos Button
        allPhotosButton = UIButton(type: .system)
        allPhotosButton.setTitle("すべての写真", for: .normal)
        allPhotosButton.setTitleColor(.systemBlue, for: .normal)
        allPhotosButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        allPhotosButton.addTarget(self, action: #selector(allPhotosButtonTapped), for: .touchUpInside)
        allPhotosButton.translatesAutoresizingMaskIntoConstraints = false
        topToolbar.addSubview(allPhotosButton)
    }
    
    private func createBottomToolbar() {
        bottomToolbar = UIView()
        bottomToolbar.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomToolbar)
    }
    
    
    private func createCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        
        let itemsPerRow: CGFloat = 3
        let paddingSpace = layout.minimumInteritemSpacing * (itemsPerRow - 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        layout.itemSize = CGSize(width: widthPerItem, height: widthPerItem)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PhotoCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // パフォーマンス最適化設定
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        
        view.addSubview(collectionView)
    }
    
    private func createPageViewController() {
        pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pageViewController.delegate = self
        pageViewController.dataSource = self
        pageViewController.view.backgroundColor = .black
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)
        
        // 初期状態では非表示
        pageViewController.view.isHidden = true
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Top Toolbar
            topToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topToolbar.heightAnchor.constraint(equalToConstant: 44),
            
            // Back Button
            backButton.leadingAnchor.constraint(equalTo: topToolbar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),
            
            // Title Label
            titleLabel.centerXAnchor.constraint(equalTo: topToolbar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),
            
            // All Photos Button
            allPhotosButton.trailingAnchor.constraint(equalTo: topToolbar.trailingAnchor, constant: -16),
            allPhotosButton.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),
            
            // Bottom Toolbar
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 80),
            
            
            // Collection View
            collectionView.topAnchor.constraint(equalTo: topToolbar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor),
            
            // Page View Controller
            pageViewController.view.topAnchor.constraint(equalTo: topToolbar.bottomAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor)
        ])
        
    }
    
    private func setupInitialState() {
        // 初期状態ではボトムツールバーを表示
        bottomToolbar.isHidden = false
    }
    
    private func setupSwipeGestures() {
        // 下から上スワイプ
        let swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUpGesture.direction = .up
        view.addGestureRecognizer(swipeUpGesture)
        
        // 左スワイプ
        let swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeftGesture.direction = .left
        view.addGestureRecognizer(swipeLeftGesture)
        
        // 右スワイプ
        let swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRightGesture.direction = .right
        view.addGestureRecognizer(swipeRightGesture)
    }
    
    @objc private func handleSwipeUp() {
        dismiss(animated: true)
    }
    
    @objc private func handleSwipeLeft() {
        dismiss(animated: true)
    }
    
    @objc private func handleSwipeRight() {
        dismiss(animated: true)
    }
    
    private func loadPhotos() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 100
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var photos: [PHAsset] = []
            
            assets.enumerateObjects { asset, _, _ in
                photos.append(asset)
            }
            
            DispatchQueue.main.async {
                self?.photos = photos
                self?.collectionView.reloadData()
                self?.setupFullscreenViewControllers()
            }
        }
    }
    
    private func setupFullscreenViewControllers() {
        fullscreenViewControllers = photos.map { asset in
            let vc = FullscreenPhotoViewController()
            vc.asset = asset
            vc.delegate = self
            return vc
        }
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        if isFullscreen {
            hideFullscreen()
        } else {
            dismiss(animated: true)
        }
    }
    
    @objc private func allPhotosButtonTapped() {
        let allPhotosVC = AllPhotosViewController()
        allPhotosVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        present(allPhotosVC, animated: true)
    }
    
    
    // MARK: - Fullscreen Methods
    
    private func showPhotoDetail(at index: Int) {
        let photoDetailVC = PhotoDetailViewController()
        photoDetailVC.asset = photos[index]
        photoDetailVC.modalPresentationStyle = .fullScreen
        present(photoDetailVC, animated: true)
    }
    
    private func hideFullscreen() {
        isFullscreen = false
        
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut], animations: {
            self.collectionView.alpha = 1
            self.bottomToolbar.alpha = 1
        }) { _ in
            self.collectionView.isHidden = false
            self.bottomToolbar.isHidden = false
            self.pageViewController.view.isHidden = true
        }
    }
}

// MARK: - UICollectionViewDataSource

extension GalleryViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! PhotoCollectionViewCell
        cell.configure(with: photos[indexPath.item])
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension GalleryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showPhotoDetail(at: indexPath.item)
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension GalleryViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // プリフェッチで画像を事前読み込み
        for indexPath in indexPaths {
            guard indexPath.item < photos.count else { continue }
            let asset = photos[indexPath.item]
            
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            
            // サムネイルサイズでプリフェッチ
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 150, height: 150), contentMode: .aspectFill, options: options) { _, _ in
                // プリフェッチ完了（結果は使用しない）
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // プリフェッチキャンセル（必要に応じて実装）
    }
}

// MARK: - UIPageViewControllerDataSource

extension GalleryViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? FullscreenPhotoViewController,
              let index = fullscreenViewControllers.firstIndex(of: vc),
              index > 0 else { return nil }
        
        return fullscreenViewControllers[index - 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let vc = viewController as? FullscreenPhotoViewController,
              let index = fullscreenViewControllers.firstIndex(of: vc),
              index < fullscreenViewControllers.count - 1 else { return nil }
        
        return fullscreenViewControllers[index + 1]
    }
}

// MARK: - UIPageViewControllerDelegate

extension GalleryViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard let vc = pageViewController.viewControllers?.first as? FullscreenPhotoViewController,
              let index = fullscreenViewControllers.firstIndex(of: vc) else { return }
        
        currentIndex = index
//        thumbnailCollectionView.reloadData()
    }
}

// MARK: - FullscreenPhotoViewControllerDelegate

extension GalleryViewController: FullscreenPhotoViewControllerDelegate {
    func didTapPhoto() {
        // 写真タップでツールバーをトグル
        let isHidden = !topToolbar.isHidden
        UIView.animate(withDuration: 0.3) {
            self.topToolbar.alpha = isHidden ? 1 : 0
            self.bottomToolbar.alpha = isHidden ? 1 : 0
        }
    }
    
    func didSwipeDown() {
        hideFullscreen()
    }
}

// MARK: - FullscreenPhotoViewController

class FullscreenPhotoViewController: UIViewController {
    var asset: PHAsset?
    weak var delegate: FullscreenPhotoViewControllerDelegate?
    
    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
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
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        // タップジェスチャー
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tapGesture)
        
        // 下スワイプジェスチャー
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDownGesture.direction = .down
        view.addGestureRecognizer(swipeDownGesture)
    }
    
    private func loadImage() {
        guard let asset = asset else { return }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }
    
    @objc private func handleTap() {
        delegate?.didTapPhoto()
    }
    
    @objc private func handleSwipeDown() {
        delegate?.didSwipeDown()
    }
}

// MARK: - UIScrollViewDelegate

extension FullscreenPhotoViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

// MARK: - FullscreenPhotoViewControllerDelegate

protocol FullscreenPhotoViewControllerDelegate: AnyObject {
    func didTapPhoto()
    func didSwipeDown()
}

// MARK: - PhotoCollectionViewCell

class PhotoCollectionViewCell: UICollectionViewCell {
    private var imageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
    
    func configure(with asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true  // iCloud画像も表示
        
        // サムネイルサイズに最適化（150x150pt）
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 150, height: 150), contentMode: .aspectFill, options: options) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
    }
}

// MARK: - AllPhotosViewController

class AllPhotosViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private var collectionView: UICollectionView!
    private var topToolbar: UIView!
    private var backButton: UIButton!
    private var titleLabel: UILabel!
    
    // MARK: - Properties
    
    private var photos: [PHAsset] = []
    private let imageManager = PHImageManager.default()
    private let cellIdentifier = "PhotoCell"
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupSwipeGestures()
        loadAllPhotos()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = .black
        
        createTopToolbar()
        createCollectionView()
        setupConstraints()
    }
    
    private func createTopToolbar() {
        topToolbar = UIView()
        topToolbar.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        topToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topToolbar)
        
        // Back Button
        backButton = UIButton(type: .system)
        backButton.setTitle("完了", for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        topToolbar.addSubview(backButton)
        
        // Title Label
        titleLabel = UILabel()
        titleLabel.text = "写真一覧"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topToolbar.addSubview(titleLabel)
        
    }
    
    private func createCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        
        let itemsPerRow: CGFloat = 3
        let paddingSpace = layout.minimumInteritemSpacing * (itemsPerRow - 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow
        
        layout.itemSize = CGSize(width: widthPerItem, height: widthPerItem)
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(AllPhotosCollectionViewCell.self, forCellWithReuseIdentifier: cellIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Top Toolbar
            topToolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topToolbar.heightAnchor.constraint(equalToConstant: 44),
            
            // Back Button
            backButton.leadingAnchor.constraint(equalTo: topToolbar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),
            
            // Title Label
            titleLabel.centerXAnchor.constraint(equalTo: topToolbar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topToolbar.centerYAnchor),
            
            
            // Collection View
            collectionView.topAnchor.constraint(equalTo: topToolbar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSwipeGestures() {
        // 下から上スワイプ
        let swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUpGesture.direction = .up
        view.addGestureRecognizer(swipeUpGesture)
        
        // 左スワイプ
        let swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeftGesture.direction = .left
        view.addGestureRecognizer(swipeLeftGesture)
        
        // 右スワイプ
        let swipeRightGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRightGesture.direction = .right
        view.addGestureRecognizer(swipeRightGesture)
    }
    
    @objc private func handleSwipeUp() {
        dismiss(animated: true)
    }
    
    @objc private func handleSwipeLeft() {
        dismiss(animated: true)
    }
    
    @objc private func handleSwipeRight() {
        dismiss(animated: true)
    }
    
    private func loadAllPhotos() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard status == .authorized else { return }
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var photos: [PHAsset] = []
            
            assets.enumerateObjects { asset, _, _ in
                photos.append(asset)
            }
            
            DispatchQueue.main.async {
                self?.photos = photos
                self?.collectionView.reloadData()
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
    
    private func showPhotoDetail(at index: Int) {
        let photoDetailVC = PhotoDetailViewController()
        photoDetailVC.asset = photos[index]
        photoDetailVC.modalPresentationStyle = UIModalPresentationStyle.fullScreen
        present(photoDetailVC, animated: true)
    }
}

// MARK: - AllPhotosViewController UICollectionViewDataSource

extension AllPhotosViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! AllPhotosCollectionViewCell
        let asset = photos[indexPath.item]
        cell.configure(with: asset)
        return cell
    }
}

// MARK: - AllPhotosViewController UICollectionViewDelegate

extension AllPhotosViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showPhotoDetail(at: indexPath.item)
    }
}


// MARK: - AllPhotosCollectionViewCell

class AllPhotosCollectionViewCell: UICollectionViewCell {
    
    private var imageView: UIImageView!
    private var selectionButton: UIButton!
    private var asset: PHAsset?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        selectionButton = UIButton(type: .system)
        selectionButton.setImage(UIImage(systemName: "circle"), for: .normal)
        selectionButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        selectionButton.tintColor = .white
        selectionButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        selectionButton.layer.cornerRadius = 12
        selectionButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(selectionButton)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            selectionButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            selectionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            selectionButton.widthAnchor.constraint(equalToConstant: 24),
            selectionButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    func configure(with asset: PHAsset) {
        self.asset = asset
        
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true  // iCloud画像も表示
        
        // サムネイルサイズに最適化（150x150pt）
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 150, height: 150), contentMode: .aspectFill, options: options) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.imageView.image = image
            }
        }
        
        selectionButton.isHidden = true
    }
    
}


