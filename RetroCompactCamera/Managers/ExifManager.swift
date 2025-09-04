import Foundation
import UIKit
import ImageIO
import CoreLocation
import Photos

class ExifManager {
    
    // MARK: - EXIF Data Generation
    
    static func generatePseudoExif(for mode: EraMode, captureDate: Date = Date()) -> [String: Any] {
        let settings = EraSettings.settings(for: mode)
        
        var exifDict: [String: Any] = [:]
        var tiffDict: [String: Any] = [:]
        var gpsDict: [String: Any] = [:]
        
        // 基本的なEXIF情報
        exifDict[kCGImagePropertyExifDateTimeOriginal as String] = formatDate(captureDate)
        exifDict[kCGImagePropertyExifDateTimeDigitized as String] = formatDate(captureDate)
        exifDict[kCGImagePropertyExifISOSpeedRatings as String] = [settings.isoValue]
        exifDict[kCGImagePropertyExifWhiteBalance as String] = 0 // Auto
        exifDict[kCGImagePropertyExifFlash as String] = settings.hasFlashEffect ? 1 : 0
        exifDict[kCGImagePropertyExifFocalLength as String] = generateFocalLength(for: mode)
        exifDict[kCGImagePropertyExifFNumber as String] = generateAperture(for: mode)
        exifDict[kCGImagePropertyExifExposureTime as String] = generateShutterSpeed()
        exifDict[kCGImagePropertyExifExposureProgram as String] = 2 // Program Auto
        exifDict[kCGImagePropertyExifMeteringMode as String] = 5 // Pattern
        exifDict[kCGImagePropertyExifColorSpace as String] = 1 // sRGB
        exifDict[kCGImagePropertyExifPixelXDimension as String] = Int(settings.resolution.width)
        exifDict[kCGImagePropertyExifPixelYDimension as String] = Int(settings.resolution.height)
        
        // TIFF情報
        tiffDict[kCGImagePropertyTIFFMake as String] = generateCameraMake(for: mode)
        tiffDict[kCGImagePropertyTIFFModel as String] = generateCameraModel(for: mode)
        tiffDict[kCGImagePropertyTIFFSoftware as String] = "Retro Compact Camera v1.0"
        tiffDict[kCGImagePropertyTIFFDateTime as String] = formatDate(captureDate)
        tiffDict[kCGImagePropertyTIFFOrientation as String] = 1
        tiffDict[kCGImagePropertyTIFFXResolution as String] = 72.0
        tiffDict[kCGImagePropertyTIFFYResolution as String] = 72.0
        tiffDict[kCGImagePropertyTIFFResolutionUnit as String] = 2
        
        // GPS情報（ダミー）
        gpsDict[kCGImagePropertyGPSLatitude as String] = 35.6762
        gpsDict[kCGImagePropertyGPSLongitude as String] = 139.6503
        gpsDict[kCGImagePropertyGPSLatitudeRef as String] = "N"
        gpsDict[kCGImagePropertyGPSLongitudeRef as String] = "E"
        gpsDict[kCGImagePropertyGPSTimeStamp as String] = formatGPSTime(captureDate)
        gpsDict[kCGImagePropertyGPSDateStamp as String] = formatGPSDate(captureDate)
        
        return [
            kCGImagePropertyExifDictionary as String: exifDict,
            kCGImagePropertyTIFFDictionary as String: tiffDict,
            kCGImagePropertyGPSDictionary as String: gpsDict
        ]
    }
    
    // MARK: - Image Saving with EXIF
    
    static func saveImageWithExif(_ image: UIImage, mode: EraMode, completion: @escaping (Bool, Error?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            completion(false, NSError(domain: "ExifManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "画像データの作成に失敗しました"]))
            return
        }
        
        let exifData = generatePseudoExif(for: mode)
        
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let type = CGImageSourceGetType(source) else {
            completion(false, NSError(domain: "ExifManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "画像ソースの作成に失敗しました"]))
            return
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else {
            completion(false, NSError(domain: "ExifManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "画像出力先の作成に失敗しました"]))
            return
        }
        
        CGImageDestinationAddImageFromSource(destination, source, 0, exifData as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            // PhotoLibraryに保存
            saveToPhotoLibrary(data: mutableData as Data, completion: completion)
        } else {
            completion(false, NSError(domain: "ExifManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "EXIF情報の付与に失敗しました"]))
        }
    }
    
    // MARK: - Private Helper Methods
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private static func formatGPSTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
    
    private static func formatGPSDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
    
    private static func generateCameraMake(for mode: EraMode) -> String {
        switch mode {
        case .earlyDigital:
            return "RetroTech"
        case .compactDigital:
            return "DigitalCorp"
        case .superzoom:
            return "ZoomMaster"
        }
    }
    
    private static func generateCameraModel(for mode: EraMode) -> String {
        switch mode {
        case .earlyDigital:
            return "EarlyDigi 200"
        case .compactDigital:
            return "CompactPro 500"
        case .superzoom:
            return "SuperZoom 800"
        }
    }
    
    private static func generateFocalLength(for mode: EraMode) -> Double {
        switch mode {
        case .earlyDigital:
            return 6.0 // 35mm換算約35mm
        case .compactDigital:
            return 7.4 // 35mm換算約42mm
        case .superzoom:
            return Double.random(in: 5.8...87.0) // 35mm換算約35-525mm
        }
    }
    
    private static func generateAperture(for mode: EraMode) -> Double {
        switch mode {
        case .earlyDigital:
            return 2.8
        case .compactDigital:
            return Double.random(in: 2.8...5.6)
        case .superzoom:
            return Double.random(in: 3.5...5.9)
        }
    }
    
    private static func generateShutterSpeed() -> Double {
        let speeds = [1.0/60.0, 1.0/125.0, 1.0/250.0, 1.0/500.0, 1.0/1000.0]
        return speeds.randomElement() ?? 1.0/125.0
    }
    
    private static func saveToPhotoLibrary(data: Data, completion: @escaping (Bool, Error?) -> Void) {
        
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                DispatchQueue.main.async {
                    completion(false, NSError(domain: "ExifManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "フォトライブラリへのアクセスが許可されていません"]))
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                DispatchQueue.main.async {
                    completion(success, error)
                }
            }
        }
    }
    
    // MARK: - EXIF Reading
    
    static func readExifData(from image: UIImage) -> [String: Any]? {
        guard let imageData = image.jpegData(compressionQuality: 1.0),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        return properties
    }
    
    static func formatExifForDisplay(_ exifData: [String: Any]) -> [(String, String)] {
        var displayData: [(String, String)] = []
        
        // 撮影日時
        if let tiffDict = exifData[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
           let dateTime = tiffDict[kCGImagePropertyTIFFDateTime as String] as? String {
            displayData.append(("撮影日時", dateTime))
        }
        
        // カメラ情報
        if let tiffDict = exifData[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let make = tiffDict[kCGImagePropertyTIFFMake as String] as? String,
               let model = tiffDict[kCGImagePropertyTIFFModel as String] as? String {
                displayData.append(("カメラ", "\(make) \(model)"))
            }
        }
        
        // ISO感度
        if let exifDict = exifData[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let isoArray = exifDict[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
           let iso = isoArray.first {
            displayData.append(("ISO感度", "ISO \(iso)"))
        }
        
        // 焦点距離
        if let exifDict = exifData[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let focalLength = exifDict[kCGImagePropertyExifFocalLength as String] as? Double {
            displayData.append(("焦点距離", String(format: "%.1fmm", focalLength)))
        }
        
        // 絞り値
        if let exifDict = exifData[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let aperture = exifDict[kCGImagePropertyExifFNumber as String] as? Double {
            displayData.append(("絞り", String(format: "F%.1f", aperture)))
        }
        
        // シャッタースピード
        if let exifDict = exifData[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let shutterSpeed = exifDict[kCGImagePropertyExifExposureTime as String] as? Double {
            if shutterSpeed >= 1 {
                displayData.append(("シャッター", String(format: "%.1fs", shutterSpeed)))
            } else {
                displayData.append(("シャッター", String(format: "1/%.0fs", 1/shutterSpeed)))
            }
        }
        
        // 解像度
        if let exifDict = exifData[kCGImagePropertyExifDictionary as String] as? [String: Any],
           let width = exifDict[kCGImagePropertyExifPixelXDimension as String] as? Int,
           let height = exifDict[kCGImagePropertyExifPixelYDimension as String] as? Int {
            displayData.append(("解像度", "\(width) × \(height)"))
        }
        
        return displayData
    }
}
