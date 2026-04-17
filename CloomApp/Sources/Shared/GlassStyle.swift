import SwiftUI

extension View {
    /// Glass capsule with a hairline edge stroke so the surface stays visible
    /// over bright or low-contrast backgrounds (e.g. white docs, video content).
    func cloomGlassCapsule() -> some View {
        glassEffect(in: .capsule)
            .overlay {
                Capsule()
                    .strokeBorder(Self.glassEdgeGradient, lineWidth: 0.5)
            }
    }

    /// Glass rounded rect with a hairline edge stroke. Use for pills that aren't
    /// full capsules (e.g. keystroke overlay).
    func cloomGlassRoundedRect(cornerRadius: CGFloat) -> some View {
        glassEffect(in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Self.glassEdgeGradient, lineWidth: 0.5)
            }
    }

    private static var glassEdgeGradient: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.30), .white.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
