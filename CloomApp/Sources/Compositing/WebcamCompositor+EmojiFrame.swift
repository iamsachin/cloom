import CoreImage
import CoreGraphics

/// Cache key for pre-rendered emoji frame images.
struct FrameImageCacheKey: Hashable {
    let frame: WebcamFrame
    let width: Int
    let height: Int
}

/// Thread-safe cache for emoji frame CGImages to avoid re-rendering every video frame.
struct FrameImageCache {
    private var cache: [FrameImageCacheKey: CGImage] = [:]

    mutating func get(key: FrameImageCacheKey) -> CGImage? {
        cache[key]
    }

    mutating func set(key: FrameImageCacheKey, image: CGImage) {
        cache[key] = image
    }

    mutating func clear() {
        cache.removeAll()
    }
}

// MARK: - Emoji Frame Rendering

extension WebcamCompositor {

    func cachedFrameImage(for layout: BubbleLayout) -> CIImage? {
        let height = layout.diameterPoints * 2
        let width = height * layout.shape.aspectRatio

        let key = FrameImageCacheKey(
            frame: layout.decoration,
            width: Int(width),
            height: Int(height)
        )

        // Check cache first
        if let cached: CGImage = frameImageCache.withLock({ $0.get(key: key) }) {
            return CIImage(cgImage: cached)
        }

        // Render at 1x — bubble dimensions are already in Retina pixels
        guard let cgImage = EmojiFrameRenderer.renderToCGImage(
            frame: layout.decoration,
            bubbleWidth: width,
            bubbleHeight: height,
            scaleFactor: 1.0
        ) else { return nil }

        frameImageCache.withLock { $0.set(key: key, image: cgImage) }
        return CIImage(cgImage: cgImage)
    }
}
