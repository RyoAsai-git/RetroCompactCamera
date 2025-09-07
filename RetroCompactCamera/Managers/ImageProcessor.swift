import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

class ImageProcessor {
    
    // MARK: - Properties
    
    private let context: CIContext
    
    // MARK: - Initialization
    
    init() {
        // Metal対応のコンテキストを作成
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            context = CIContext(mtlDevice: metalDevice)
        } else {
            context = CIContext()
        }
    }
    
    // MARK: - Main Processing Method
    
    func processImage(_ image: UIImage, with mode: EraMode) -> UIImage? {
        guard let inputImage = CIImage(image: image) else { return nil }
        
        let settings = EraSettings.settings(for: mode)
        var processedImage = inputImage
        
        // 解像度調整
        processedImage = resizeImage(processedImage, to: settings.resolution)
        
        // カラー調整
        processedImage = adjustColors(processedImage, settings: settings)
        
        // シャープネス調整
        processedImage = adjustSharpness(processedImage, intensity: settings.sharpness)
        
        // ノイズ追加
        processedImage = addNoise(processedImage, intensity: settings.noiseLevel)
        
        // ビネット効果
        processedImage = addVignette(processedImage, intensity: settings.vignetteIntensity)
        
        // モーションブラー（Superzoomモードのみ）
        if settings.hasMotionBlur {
            processedImage = addMotionBlur(processedImage)
        }
        
        // CGImageに変換
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return nil
        }
        
        let processedUIImage = UIImage(cgImage: cgImage)
        
        // 日付オーバーレイを最終段階で追加（余白問題を避けるため）
        return addDateOverlayToUIImage(processedUIImage)
    }
    
    // MARK: - Individual Processing Methods
    
    private func resizeImage(_ image: CIImage, to size: CGSize) -> CIImage {
        // アスペクト比を保持してリサイズ（余白を避ける）
        let scaleX = size.width / image.extent.width
        let scaleY = size.height / image.extent.height
        let scale = min(scaleX, scaleY) // 元に戻す
        
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return image.transformed(by: transform)
    }
    
    private func adjustColors(_ image: CIImage, settings: EraSettings) -> CIImage {
        // 色温度調整
        let temperatureFilter = CIFilter.temperatureAndTint()
        temperatureFilter.inputImage = image
        temperatureFilter.neutral = CIVector(x: CGFloat(settings.colorTemperature), y: 0)
        
        guard let tempAdjusted = temperatureFilter.outputImage else { return image }
        
        // 彩度・コントラスト調整
        let colorControlsFilter = CIFilter.colorControls()
        colorControlsFilter.inputImage = tempAdjusted
        colorControlsFilter.saturation = settings.saturation
        colorControlsFilter.contrast = settings.contrast
        
        return colorControlsFilter.outputImage ?? image
    }
    
    private func adjustSharpness(_ image: CIImage, intensity: Float) -> CIImage {
        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = image
        sharpenFilter.sharpness = intensity
        
        return sharpenFilter.outputImage ?? image
    }
    
    private func addNoise(_ image: CIImage, intensity: Float) -> CIImage {
        // ランダムノイズを生成
        let noiseFilter = CIFilter.randomGenerator()
        guard let noiseImage = noiseFilter.outputImage else { return image }
        
        // ノイズをクロップして画像サイズに合わせる
        let croppedNoise = noiseImage.cropped(to: image.extent)
        
        // ノイズの強度を調整
        let colorMatrix = CIFilter.colorMatrix()
        colorMatrix.inputImage = croppedNoise
        colorMatrix.aVector = CIVector(x: 0, y: 0, z: 0, w: CGFloat(intensity))
        
        guard let adjustedNoise = colorMatrix.outputImage else { return image }
        
        // 元の画像とノイズを合成
        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.inputImage = adjustedNoise
        blendFilter.backgroundImage = image
        
        return blendFilter.outputImage ?? image
    }
    
    private func addVignette(_ image: CIImage, intensity: Float) -> CIImage {
        let vignetteFilter = CIFilter.vignette()
        vignetteFilter.inputImage = image
        vignetteFilter.intensity = intensity
        vignetteFilter.radius = 1.0
        
        return vignetteFilter.outputImage ?? image
    }
    
    private func addMotionBlur(_ image: CIImage) -> CIImage {
        // ランダムな方向と強度でモーションブラーを追加
        let angle = Float.random(in: 0...360) * .pi / 180
        let radius = Float.random(in: 2...8)
        
        let motionBlurFilter = CIFilter.motionBlur()
        motionBlurFilter.inputImage = image
        motionBlurFilter.angle = angle
        motionBlurFilter.radius = radius
        
        return motionBlurFilter.outputImage ?? image
    }
    
    // MARK: - Flash Effect
    
    func addFlashEffect(to image: UIImage) -> UIImage? {
        guard let inputImage = CIImage(image: image) else { return nil }
        
        // 白飛び効果を追加
        let exposureFilter = CIFilter.exposureAdjust()
        exposureFilter.inputImage = inputImage
        exposureFilter.ev = 0.5
        
        guard let flashImage = exposureFilter.outputImage,
              let cgImage = context.createCGImage(flashImage, from: flashImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Lens Distortion
    
    func addLensDistortion(to image: CIImage, intensity: Float = 0.1) -> CIImage {
        let distortionFilter = CIFilter.bumpDistortion()
        distortionFilter.inputImage = image
        distortionFilter.center = CGPoint(x: image.extent.midX, y: image.extent.midY)
        distortionFilter.radius = Float(min(image.extent.width, image.extent.height) * 0.4)
        distortionFilter.scale = intensity
        
        return distortionFilter.outputImage ?? image
    }
    
    // MARK: - Date Overlay
    
    private func addDateOverlayToUIImage(_ image: UIImage) -> UIImage? {
        // 現在の日付と時刻をYYYY/MM/DD HH:mm:ss形式で取得
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        // 日付テキストの画像を生成
        guard let dateImage = createDateTextImage(text: dateString, size: image.size) else {
            return image
        }
        
        // 元の画像に日付を描画
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { context in
            // 元の画像を描画
            image.draw(in: CGRect(origin: .zero, size: image.size))
            
            // 日付を右下角に描画
            let margin: CGFloat = 20
            let dateSize = dateImage.size
            let x = image.size.width - dateSize.width - margin
            let y = image.size.height - dateSize.height - margin
            
            dateImage.draw(in: CGRect(x: x, y: y, width: dateSize.width, height: dateSize.height))
        }
    }
    
    private func addDateOverlay(_ image: CIImage) -> CIImage {
        // 現在の日付と時刻をYYYY/MM/DD HH:mm:ss形式で取得
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        let dateString = dateFormatter.string(from: Date())
        
        // 日付テキストの画像を生成
        guard let dateImage = createDateTextImage(text: dateString, size: image.extent.size) else {
            return image
        }
        
        // 日付画像をCIImageに変換
        guard let dateCIImage = CIImage(image: dateImage) else {
            return image
        }
        
        // 日付の位置を計算（右下角）
        let margin: CGFloat = 20
        let dateSize = dateImage.size
        let x = image.extent.width - dateSize.width - margin
        let y = image.extent.height - dateSize.height - margin // 正しい右下角の位置
        
        // 日付画像を適切な位置に配置
        let transform = CGAffineTransform(translationX: x, y: y)
        let positionedDateImage = dateCIImage.transformed(by: transform)
        
        // 元の画像と日付画像を合成
        let blendFilter = CIFilter.sourceOverCompositing()
        blendFilter.inputImage = positionedDateImage
        blendFilter.backgroundImage = image
        
        return blendFilter.outputImage ?? image
    }
    
    private func createDateTextImage(text: String, size: CGSize) -> UIImage? {
        // 参考画像に合わせて小さなフォントサイズに調整
        let fontSize = min(size.width, size.height) * 0.015 // 画面サイズの1.5%に縮小
        let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
        
        // テキストのサイズを計算
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        
        let textSize = text.size(withAttributes: attributes)
        
        // 影効果のための余白を追加（重なりを防ぐため適切なサイズに）
        let shadowOffset: CGFloat = 1
        let imageSize = CGSize(
            width: textSize.width + shadowOffset * 2,
            height: textSize.height + shadowOffset * 2
        )
        
        // 画像を生成
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // 背景を透明にする
            cgContext.clear(CGRect(origin: .zero, size: imageSize))
            
            // 影を描画（暗い色で視認性を向上）
            let shadowColor = UIColor.black.withAlphaComponent(0.6)
            let shadowAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: shadowColor
            ]
            
            let shadowRect = CGRect(
                x: shadowOffset,
                y: shadowOffset,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: shadowRect, withAttributes: shadowAttributes)
            
            // メインテキストを描画（白で視認性を向上）
            let mainColor = UIColor.white
            let mainAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: mainColor
            ]
            
            let mainRect = CGRect(
                x: 0,
                y: 0,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: mainRect, withAttributes: mainAttributes)
        }
    }
}
