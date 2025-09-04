import Foundation
import UIKit

// MARK: - Era Mode Types

enum EraMode: CaseIterable {
    case earlyDigital    // 2000年代前期
    case compactDigital  // 2000年代中期
    case superzoom       // 2000年代後期
    
    var displayName: String {
        switch self {
        case .earlyDigital:
            return "Early Digital"
        case .compactDigital:
            return "Compact Digital"
        case .superzoom:
            return "Superzoom"
        }
    }
    
    var description: String {
        switch self {
        case .earlyDigital:
            return "2000年代前期\n低解像度・青被り"
        case .compactDigital:
            return "2000年代中期\nバランス良い発色"
        case .superzoom:
            return "2000年代後期\n手ブレ・高感度ノイズ"
        }
    }
    
    var icon: String {
        switch self {
        case .earlyDigital:
            return "camera.fill"
        case .compactDigital:
            return "camera.macro"
        case .superzoom:
            return "camera.aperture"
        }
    }
}

// MARK: - Era Settings

struct EraSettings {
    let resolution: CGSize
    let noiseLevel: Float
    let colorTemperature: Float
    let saturation: Float
    let contrast: Float
    let sharpness: Float
    let vignetteIntensity: Float
    let hasMotionBlur: Bool
    let hasFlashEffect: Bool
    let hasFaceDetection: Bool
    let isoValue: Int
    let whiteBalance: String
    
    static func settings(for mode: EraMode) -> EraSettings {
        switch mode {
        case .earlyDigital:
            return EraSettings(
                resolution: CGSize(width: 640, height: 480),
                noiseLevel: 0.3,
                colorTemperature: 7000, // 青被り
                saturation: 0.7,
                contrast: 0.8,
                sharpness: 0.5,
                vignetteIntensity: 0.2,
                hasMotionBlur: false,
                hasFlashEffect: false,
                hasFaceDetection: false,
                isoValue: 200,
                whiteBalance: "Auto"
            )
        case .compactDigital:
            return EraSettings(
                resolution: CGSize(width: 1600, height: 1200),
                noiseLevel: 0.15,
                colorTemperature: 5500, // バランス良い
                saturation: 1.0,
                contrast: 1.1,
                sharpness: 0.8,
                vignetteIntensity: 0.1,
                hasMotionBlur: false,
                hasFlashEffect: true,
                hasFaceDetection: true,
                isoValue: 400,
                whiteBalance: "Auto"
            )
        case .superzoom:
            return EraSettings(
                resolution: CGSize(width: 2048, height: 1536),
                noiseLevel: 0.4,
                colorTemperature: 5000,
                saturation: 0.9,
                contrast: 1.2,
                sharpness: 1.0,
                vignetteIntensity: 0.15,
                hasMotionBlur: true,
                hasFlashEffect: true,
                hasFaceDetection: true,
                isoValue: 800,
                whiteBalance: "Auto"
            )
        }
    }
}

// MARK: - Camera UI Configuration

struct CameraUIConfig {
    let showBatteryIndicator: Bool
    let showDateTimeOverlay: Bool
    let showRecordingIndicator: Bool
    let focusFrameColor: UIColor
    let overlayTextColor: UIColor
    let backgroundColor: UIColor
    
    static func config(for mode: EraMode) -> CameraUIConfig {
        switch mode {
        case .earlyDigital:
            return CameraUIConfig(
                showBatteryIndicator: true,
                showDateTimeOverlay: true,
                showRecordingIndicator: false,
                focusFrameColor: .green,
                overlayTextColor: .white,
                backgroundColor: .black
            )
        case .compactDigital:
            return CameraUIConfig(
                showBatteryIndicator: true,
                showDateTimeOverlay: true,
                showRecordingIndicator: false,
                focusFrameColor: .green,
                overlayTextColor: .white,
                backgroundColor: .black
            )
        case .superzoom:
            return CameraUIConfig(
                showBatteryIndicator: true,
                showDateTimeOverlay: true,
                showRecordingIndicator: true,
                focusFrameColor: .red,
                overlayTextColor: .red,
                backgroundColor: .black
            )
        }
    }
}
