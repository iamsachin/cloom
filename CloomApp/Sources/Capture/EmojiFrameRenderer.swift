import AppKit
import CoreGraphics
import CoreText

/// Positioned sticker with Cartesian coordinates, ready for rendering.
struct PositionedSticker: Sendable {
    let emoji: String
    let x: CGFloat
    let y: CGFloat
    let fontSize: CGFloat
    let rotationDegrees: CGFloat
}

enum EmojiFrameRenderer {
    /// How far emojis may extend beyond the bubble edge (points, at 180pt baseline).
    static let baseFramePadding: CGFloat = 36

    /// Scaled frame padding for the given bubble diameter.
    static func framePadding(for bubbleDiameter: CGFloat) -> CGFloat {
        baseFramePadding * (bubbleDiameter / 180.0)
    }

    /// Converts polar sticker definitions to Cartesian positions relative to a bounding box
    /// of size `(bubbleWidth + pad*2, bubbleHeight + pad*2)` with the bubble centered.
    static func positionStickers(
        frame: WebcamFrame,
        bubbleWidth: CGFloat,
        bubbleHeight: CGFloat
    ) -> [PositionedSticker] {
        guard frame != .none else { return [] }

        let scale = min(bubbleWidth, bubbleHeight) / 180.0
        let pad = framePadding(for: min(bubbleWidth, bubbleHeight))

        let rx = bubbleWidth / 2.0
        let ry = bubbleHeight / 2.0
        let cx = rx + pad
        let cy = ry + pad

        return frame.stickers.map { sticker in
            let angle = sticker.angleDegrees * .pi / 180.0
            let offset = sticker.offsetFromEdge * scale

            // Point on ellipse perimeter + offset outward
            let ex = rx * cos(angle)
            let ey = ry * sin(angle)
            let norm = sqrt(ex * ex + ey * ey)
            let dirX = norm > 0 ? ex / norm : 1
            let dirY = norm > 0 ? ey / norm : 0

            let x = cx + ex + dirX * offset
            let y = cy + ey + dirY * offset
            let fontSize = sticker.baseFontSize * scale

            return PositionedSticker(
                emoji: sticker.emoji,
                x: x,
                y: y,
                fontSize: fontSize,
                rotationDegrees: sticker.rotationDegrees
            )
        }
    }

    /// Renders all emojis to a CGImage for compositor use.
    /// The image covers `(bubbleWidth + pad*2, bubbleHeight + pad*2)`.
    static func renderToCGImage(
        frame: WebcamFrame,
        bubbleWidth: CGFloat,
        bubbleHeight: CGFloat,
        scaleFactor: CGFloat = 2.0
    ) -> CGImage? {
        guard frame != .none else { return nil }

        let pad = framePadding(for: min(bubbleWidth, bubbleHeight))
        let totalWidth = bubbleWidth + pad * 2
        let totalHeight = bubbleHeight + pad * 2

        let pixelW = Int(totalWidth * scaleFactor)
        let pixelH = Int(totalHeight * scaleFactor)

        guard let ctx = CGContext(
            data: nil, width: pixelW, height: pixelH,
            bitsPerComponent: 8, bytesPerRow: pixelW * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.scaleBy(x: scaleFactor, y: scaleFactor)

        let stickers = positionStickers(
            frame: frame,
            bubbleWidth: bubbleWidth,
            bubbleHeight: bubbleHeight
        )

        // Flip Y: positionStickers uses math convention (Y-up) but CGContext
        // needs screen convention (Y-down) to match SwiftUI preview visually.
        for sticker in stickers {
            let flipped = PositionedSticker(
                emoji: sticker.emoji,
                x: sticker.x,
                y: totalHeight - sticker.y,
                fontSize: sticker.fontSize,
                rotationDegrees: sticker.rotationDegrees
            )
            drawEmoji(flipped, in: ctx)
        }

        return ctx.makeImage()
    }

    /// Draws a single emoji into a CGContext using CoreText.
    private static func drawEmoji(_ sticker: PositionedSticker, in ctx: CGContext) {
        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, sticker.fontSize, nil)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
        ]
        let attrStr = NSAttributedString(string: sticker.emoji, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)

        // Measure glyph bounds for centering
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let lineHeight = ascent + descent

        ctx.saveGState()

        // Move to sticker center, apply rotation, then offset to draw baseline
        ctx.translateBy(x: sticker.x, y: sticker.y)
        if sticker.rotationDegrees != 0 {
            ctx.rotate(by: sticker.rotationDegrees * .pi / 180.0)
        }
        ctx.translateBy(x: -lineWidth / 2, y: -lineHeight / 2 + descent)

        ctx.textPosition = .zero
        CTLineDraw(line, ctx)

        ctx.restoreGState()
    }
}
