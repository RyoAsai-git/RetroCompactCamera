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
        
        // CGImageに変換して返す
        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Individual Processing Methods
    
    private func resizeImage(_ image: CIImage, to size: CGSize) -> CIImage {
        let scaleX = size.width / image.extent.width
        let scaleY = size.height / image.extent.height
        let scale = min(scaleX, scaleY)
        
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
}
