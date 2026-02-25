import CoreImage
import CoreGraphics

private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

// MARK: - Shape Masks

extension WebcamCompositor {

    func makeShapeMask(shape: WebcamShape, extent: CGRect) -> CIImage? {
        switch shape {
        case .circle:
            return makeCircleMask(
                center: CGPoint(x: extent.midX, y: extent.midY),
                radius: extent.height / 2.0,
                extent: extent
            )
        case .roundedRect, .pill:
            return makeRoundedRectMask(shape: shape, extent: extent)
        }
    }

    private func makeCircleMask(center: CGPoint, radius: CGFloat, extent: CGRect) -> CIImage? {
        guard let filter = CIFilter(name: "CIRadialGradient") else { return nil }
        filter.setValue(CIVector(x: center.x, y: center.y), forKey: "inputCenter")
        filter.setValue(radius - 1, forKey: "inputRadius0")
        filter.setValue(radius, forKey: "inputRadius1")
        filter.setValue(CIColor.white, forKey: "inputColor0")
        filter.setValue(CIColor.clear, forKey: "inputColor1")
        return filter.outputImage?.cropped(to: extent)
    }

    private func makeRoundedRectMask(shape: WebcamShape, extent: CGRect) -> CIImage? {
        let cacheKey = ShapeMaskCacheKey(shape: shape, width: extent.width, height: extent.height)
        if let cached: CIImage = maskCache.withLock({ $0.get(cacheKey) }) {
            return cached.transformed(by: CGAffineTransform(translationX: extent.origin.x, y: extent.origin.y))
        }

        let width = Int(extent.width)
        let height = Int(extent.height)
        let cornerRadius = shape.cornerRadius(forHeight: extent.height)

        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: sRGBColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()

        guard let cgImage = ctx.makeImage() else { return nil }
        let maskImage = CIImage(cgImage: cgImage)

        maskCache.withLock { $0.set(cacheKey, value: maskImage) }

        return maskImage.transformed(by: CGAffineTransform(translationX: extent.origin.x, y: extent.origin.y))
    }
}

// MARK: - Shape Mask Cache

struct ShapeMaskCacheKey: Hashable {
    let shape: WebcamShape
    let width: CGFloat
    let height: CGFloat
}

struct ShapeMaskCache {
    private var cache: [ShapeMaskCacheKey: CIImage] = [:]

    func get(_ key: ShapeMaskCacheKey) -> CIImage? {
        cache[key]
    }

    mutating func set(_ key: ShapeMaskCacheKey, value: CIImage) {
        if cache.count > 3 {
            cache.removeAll()
        }
        cache[key] = value
    }
}
