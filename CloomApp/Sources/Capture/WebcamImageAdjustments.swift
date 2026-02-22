import CoreImage
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "WebcamImageAdjuster")

struct WebcamAdjustments: Sendable, Codable, Equatable {
    var brightness: Float = 0      // CIColorControls -1..1
    var contrast: Float = 1        // CIColorControls 0..4
    var saturation: Float = 1      // CIColorControls 0..2
    var highlights: Float = 1      // CIHighlightShadowAdjust 0..1
    var shadows: Float = 0         // CIHighlightShadowAdjust -1..1
    var temperature: Float = 6500  // CITemperatureAndTint 2000..10000
    var tint: Float = 0            // CITemperatureAndTint -150..150

    static let `default` = WebcamAdjustments()

    var isDefault: Bool {
        self == .default
    }
}

final class WebcamImageAdjuster: @unchecked Sendable {
    private let state: OSAllocatedUnfairLock<WebcamAdjustments>

    init(adjustments: WebcamAdjustments = .default) {
        self.state = OSAllocatedUnfairLock(initialState: adjustments)
    }

    func updateAdjustments(_ adjustments: WebcamAdjustments) {
        state.withLock { $0 = adjustments }
    }

    func apply(to image: CIImage) -> CIImage {
        let adj: WebcamAdjustments = state.withLock { $0 }

        guard !adj.isDefault else { return image }

        var result = image

        // CIColorControls: brightness, contrast, saturation
        let needsColorControls = adj.brightness != 0 || adj.contrast != 1 || adj.saturation != 1
        if needsColorControls {
            result = result.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: adj.brightness,
                kCIInputContrastKey: adj.contrast,
                kCIInputSaturationKey: adj.saturation,
            ])
        }

        // CIHighlightShadowAdjust: highlights, shadows
        let needsHighlightShadow = adj.highlights != 1 || adj.shadows != 0
        if needsHighlightShadow {
            result = result.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": adj.highlights,
                "inputShadowAmount": adj.shadows,
            ])
        }

        // CITemperatureAndTint: temperature, tint
        let needsTemperature = adj.temperature != 6500 || adj.tint != 0
        if needsTemperature {
            result = result.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: CGFloat(adj.temperature), y: CGFloat(adj.tint)),
                "inputTargetNeutral": CIVector(x: 6500, y: 0),
            ])
        }

        return result
    }
}
