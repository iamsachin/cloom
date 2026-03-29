import Testing
import CoreGraphics
import CoreImage
@testable import Cloom

// MARK: - Task 227: Social Media Export Preset Tests

@Suite("SocialAspectRatio")
struct SocialAspectRatioTests {

    @Test func allCasesExist() {
        #expect(SocialAspectRatio.allCases.count == 4)
    }

    @Test func aspectRatioValues() {
        #expect(SocialAspectRatio.landscape_16_9.aspectRatio == 16.0 / 9.0)
        #expect(SocialAspectRatio.vertical_9_16.aspectRatio == 9.0 / 16.0)
        #expect(SocialAspectRatio.square_1_1.aspectRatio == 1.0)
        #expect(SocialAspectRatio.portrait_4_5.aspectRatio == 4.0 / 5.0)
    }

    @Test func outputSizeDefault1080() {
        let vertical = SocialAspectRatio.vertical_9_16.outputSize()
        #expect(vertical.width == 1080)
        #expect(vertical.height == 1920)

        let square = SocialAspectRatio.square_1_1.outputSize()
        #expect(square.width == 1080)
        #expect(square.height == 1080)

        let portrait = SocialAspectRatio.portrait_4_5.outputSize()
        #expect(portrait.width == 1080)
        #expect(portrait.height == 1350)

        let landscape = SocialAspectRatio.landscape_16_9.outputSize()
        #expect(landscape.width == 1920)
        #expect(landscape.height == 1080)
    }

    @Test func outputSizeCustomShortEdge() {
        let size = SocialAspectRatio.vertical_9_16.outputSize(shortEdge: 720)
        #expect(size.width == 720)
        #expect(size.height == 1280)
    }

    @Test func labelsNotEmpty() {
        for preset in SocialAspectRatio.allCases {
            #expect(!preset.label.isEmpty)
            #expect(!preset.platformLabel.isEmpty)
        }
    }
}

@Suite("reframeCropRect")
struct CropRectTests {

    private let landscape1080p = CGSize(width: 1920, height: 1080)

    @Test func centeredSquareCrop() {
        let rect = reframeCropRect(
            for: .square_1_1,
            in: landscape1080p
        )
        // Square crop from 1920x1080 → 1080x1080 centered
        #expect(rect.width == 1080)
        #expect(rect.height == 1080)
        #expect(rect.origin.x == 420) // (1920 - 1080) / 2
        #expect(rect.origin.y == 0)
    }

    @Test func centeredVerticalCrop() {
        let rect = reframeCropRect(
            for: .vertical_9_16,
            in: landscape1080p
        )
        // 9:16 crop from 1920x1080 → 607.5x1080 centered
        let expectedWidth = 1080.0 * (9.0 / 16.0)
        #expect(abs(rect.width - expectedWidth) < 0.01)
        #expect(rect.height == 1080)
        let expectedX = (1920 - expectedWidth) / 2.0
        #expect(abs(rect.origin.x - expectedX) < 0.01)
        #expect(rect.origin.y == 0)
    }

    @Test func focusLeftEdge() {
        let rect = reframeCropRect(
            for: .square_1_1,
            in: landscape1080p,
            focusX: 0.0
        )
        // Focus at left edge → crop clamped to x=0
        #expect(rect.origin.x == 0)
        #expect(rect.width == 1080)
    }

    @Test func focusRightEdge() {
        let rect = reframeCropRect(
            for: .square_1_1,
            in: landscape1080p,
            focusX: 1.0
        )
        // Focus at right edge → crop clamped to x = 1920 - 1080 = 840
        #expect(rect.origin.x == 840)
    }

    @Test func focusClampedToBounds() {
        let rect = reframeCropRect(
            for: .square_1_1,
            in: landscape1080p,
            focusX: 0.1,
            focusY: 0.5
        )
        // focusX=0.1 → idealX = 0.1*1920 - 540 = -348 → clamped to 0
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
    }

    @Test func portraitSource() {
        let portraitSource = CGSize(width: 1080, height: 1920)
        let rect = reframeCropRect(
            for: .square_1_1,
            in: portraitSource
        )
        // Square crop from 1080x1920 → 1080x1080 centered vertically
        #expect(rect.width == 1080)
        #expect(rect.height == 1080)
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 420) // (1920 - 1080) / 2
    }

    @Test func landscapeOriginalPreset() {
        let rect = reframeCropRect(
            for: .landscape_16_9,
            in: landscape1080p
        )
        // Same aspect ratio → full frame
        #expect(abs(rect.width - 1920) < 0.01)
        #expect(abs(rect.height - 1080) < 0.01)
        #expect(abs(rect.origin.x) < 0.01)
        #expect(abs(rect.origin.y) < 0.01)
    }

    @Test func fourByFiveCrop() {
        let rect = reframeCropRect(
            for: .portrait_4_5,
            in: landscape1080p
        )
        // 4:5 crop from 1920x1080 → 864x1080 centered
        let expectedWidth = 1080.0 * (4.0 / 5.0)
        #expect(abs(rect.width - expectedWidth) < 0.01)
        #expect(rect.height == 1080)
    }
}

@Suite("BackgroundFillStyle")
struct BackgroundFillStyleTests {

    @Test func defaultsExist() {
        // Just verify these don't crash
        _ = BackgroundFillStyle.defaultBlur
        _ = BackgroundFillStyle.defaultSolid
        _ = BackgroundFillStyle.defaultGradient
    }

    @Test func equality() {
        #expect(BackgroundFillStyle.defaultBlur == BackgroundFillStyle.blur(radius: 30))
        #expect(BackgroundFillStyle.defaultBlur != BackgroundFillStyle.blur(radius: 20))
        #expect(BackgroundFillStyle.defaultSolid != BackgroundFillStyle.defaultBlur)
    }
}

@Suite("ReframeConfig")
struct ReframeConfigTests {

    @Test func defaultFocusCenter() {
        let config = ReframeConfig(aspectRatio: .vertical_9_16)
        #expect(config.focusX == 0.5)
        #expect(config.focusY == 0.5)
        #expect(config.outputSize.width == 1080)
        #expect(config.outputSize.height == 1920)
    }

    @Test func customFocusPoint() {
        let config = ReframeConfig(
            aspectRatio: .square_1_1,
            focusX: 0.3,
            focusY: 0.7
        )
        #expect(config.focusX == 0.3)
        #expect(config.focusY == 0.7)
        #expect(config.outputSize.width == 1080)
        #expect(config.outputSize.height == 1080)
    }
}

@Suite("ReframeCompositor.cropAndScale")
struct CropAndScaleTests {

    @Test func cropAndScaleMovesToOrigin() {
        let source = CIImage(color: .red).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let cropRect = CGRect(x: 420, y: 0, width: 1080, height: 1080)
        let targetSize = CGSize(width: 1080, height: 1080)

        let result = ReframeCompositor.cropAndScale(source, cropRect: cropRect, targetSize: targetSize)

        #expect(result.extent.origin.x == 0)
        #expect(result.extent.origin.y == 0)
        #expect(abs(result.extent.width - 1080) < 1)
        #expect(abs(result.extent.height - 1080) < 1)
    }

    @Test func cropAndScaleToSmallerSize() {
        let source = CIImage(color: .blue).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let cropRect = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let targetSize = CGSize(width: 960, height: 540)

        let result = ReframeCompositor.cropAndScale(source, cropRect: cropRect, targetSize: targetSize)

        #expect(result.extent.origin.x == 0)
        #expect(result.extent.origin.y == 0)
        #expect(abs(result.extent.width - 960) < 1)
        #expect(abs(result.extent.height - 540) < 1)
    }
}

@Suite("ReframeCompositor.makeBackground")
struct MakeBackgroundTests {

    private let sourceSize = CGSize(width: 1920, height: 1080)
    private let outputSize = CGSize(width: 1080, height: 1920)

    @Test func solidColorFillsOutputRect() {
        let source = CIImage(color: .red).cropped(to: CGRect(origin: .zero, size: sourceSize))
        let bg = ReframeCompositor.makeBackground(
            from: source,
            sourceSize: sourceSize,
            outputSize: outputSize,
            fillStyle: .solidColor(red: 0, green: 0, blue: 0, alpha: 1)
        )
        #expect(bg.extent.width == outputSize.width)
        #expect(bg.extent.height == outputSize.height)
    }

    @Test func gradientFillsOutputRect() {
        let source = CIImage(color: .red).cropped(to: CGRect(origin: .zero, size: sourceSize))
        let bg = ReframeCompositor.makeBackground(
            from: source,
            sourceSize: sourceSize,
            outputSize: outputSize,
            fillStyle: .defaultGradient
        )
        #expect(bg.extent.width == outputSize.width)
        #expect(bg.extent.height == outputSize.height)
    }

    @Test func blurFillsOutputRect() {
        let source = CIImage(color: .red).cropped(to: CGRect(origin: .zero, size: sourceSize))
        let bg = ReframeCompositor.makeBackground(
            from: source,
            sourceSize: sourceSize,
            outputSize: outputSize,
            fillStyle: .blur(radius: 30)
        )
        #expect(bg.extent.width == outputSize.width)
        #expect(bg.extent.height == outputSize.height)
    }
}

@Suite("ReframeCompositor.renderPreview")
struct RenderPreviewTests {

    @Test func renderPreviewReturnsImage() {
        let source = CIImage(color: .green).cropped(to: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let config = ReframeConfig(aspectRatio: .vertical_9_16)

        let cgImage = ReframeCompositor.renderPreview(
            from: source,
            config: config,
            previewWidth: 200
        )

        #expect(cgImage != nil)
        if let cgImage {
            let scale = 200.0 / 1080.0
            let expectedHeight = Int(1920.0 * scale)
            #expect(cgImage.width == 200)
            #expect(abs(cgImage.height - expectedHeight) <= 1)
        }
    }

    @Test func renderPreviewWithEmptySourceReturnsNil() {
        let emptyImage = CIImage.empty()
        let config = ReframeConfig(aspectRatio: .square_1_1)

        let cgImage = ReframeCompositor.renderPreview(
            from: emptyImage,
            config: config,
            previewWidth: 200
        )

        #expect(cgImage == nil)
    }
}
