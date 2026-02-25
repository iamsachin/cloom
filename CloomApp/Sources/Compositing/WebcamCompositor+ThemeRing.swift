import CoreImage
import CoreGraphics

private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

// MARK: - Theme Ring Rendering

extension WebcamCompositor {

    func makeThemeRing(theme: BubbleTheme, shape: WebcamShape, size: CGSize, origin: CGPoint) -> CIImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let cornerRadius = shape.cornerRadius(forHeight: size.height)

        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: sRGBColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

        if let gradientColors = theme.gradientCGColors() {
            guard let gradient = CGGradient(
                colorsSpace: sRGBColorSpace,
                colors: [gradientColors.0, gradientColors.1] as CFArray,
                locations: [0, 1]
            ) else { return nil }
            ctx.addPath(path)
            ctx.clip()
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: CGFloat(height)),
                end: CGPoint(x: CGFloat(width), y: 0),
                options: []
            )
        } else if let solidColor = theme.cgColor() {
            ctx.setFillColor(solidColor)
            ctx.addPath(path)
            ctx.fillPath()
        } else {
            return nil
        }

        guard let cgImage = ctx.makeImage() else { return nil }
        return CIImage(cgImage: cgImage)
            .transformed(by: CGAffineTransform(translationX: origin.x, y: origin.y))
    }
}
