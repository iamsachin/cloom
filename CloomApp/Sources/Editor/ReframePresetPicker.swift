import SwiftUI
import AVFoundation
import CoreImage

// MARK: - Preset Buttons (always shown at top)

/// Horizontal row of aspect ratio preset buttons.
struct ReframePresetButtons: View {
    @Binding var selectedPreset: SocialAspectRatio?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aspect Ratio").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                presetButton(nil, label: "Original", icon: "rectangle")
                ForEach(SocialAspectRatio.allCases) { preset in
                    presetButton(preset, label: preset.label, icon: iconName(for: preset))
                }
            }
        }
    }

    private func presetButton(
        _ preset: SocialAspectRatio?,
        label: String,
        icon: String
    ) -> some View {
        let isSelected = selectedPreset == preset
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedPreset = preset
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(height: 24)
                Text(label)
                    .font(.caption2)
                if let preset {
                    Text(preset.platformLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private func iconName(for preset: SocialAspectRatio) -> String {
        switch preset {
        case .landscape_16_9: "rectangle"
        case .vertical_9_16: "rectangle.portrait"
        case .square_1_1: "square"
        case .portrait_4_5: "rectangle.portrait"
        }
    }
}

// MARK: - Preview Column (left side of two-column layout)

/// Live preview + background fill picker, shown in the left column when a preset is selected.
struct ReframePreviewColumn: View {
    let videoFilePath: String
    let selectedPreset: SocialAspectRatio?
    @Binding var backgroundFill: BackgroundFillStyle
    @Binding var focusX: Double
    @Binding var focusY: Double

    @State private var sourceImage: CIImage?
    @State private var previewCGImage: CGImage?

    private let previewWidth: CGFloat = 240

    var body: some View {
        VStack(spacing: 12) {
            previewSection
            backgroundFillPicker
        }
        .task { await loadSourceFrame() }
        .onChange(of: selectedPreset) { _, _ in updatePreview() }
        .onChange(of: backgroundFill) { _, _ in updatePreview() }
        .onChange(of: focusX) { _, _ in updatePreview() }
        .onChange(of: focusY) { _, _ in updatePreview() }
    }

    // MARK: - Preview

    @ViewBuilder
    private var previewSection: some View {
        if let preset = selectedPreset {
            let outputSize = preset.outputSize()
            let scale = previewWidth / outputSize.width
            let previewHeight = min(outputSize.height * scale, 320)

            VStack(spacing: 6) {
                ZStack {
                    if let previewCGImage {
                        Image(decorative: previewCGImage, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: previewWidth, height: previewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.quaternary)
                            .frame(width: previewWidth, height: previewHeight)
                            .overlay { ProgressView() }
                    }

                    focusDragOverlay(previewWidth: previewWidth, previewHeight: previewHeight)
                }
                .frame(width: previewWidth, height: previewHeight)

                Text("Drag crosshair to adjust focus")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func focusDragOverlay(previewWidth: CGFloat, previewHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let posX = focusX * geo.size.width
            let posY = focusY * geo.size.height

            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .background(Circle().fill(.white.opacity(0.15)))
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.5), radius: 2)
                .position(x: posX, y: posY)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            focusX = max(0, min(1, value.location.x / geo.size.width))
                            focusY = max(0, min(1, value.location.y / geo.size.height))
                        }
                )
        }
        .frame(width: previewWidth, height: previewHeight)
    }

    // MARK: - Background Fill

    private var backgroundFillPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Background").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                fillButton(.defaultBlur, label: "Blur", icon: "aqi.medium")
                fillButton(.defaultSolid, label: "Black", icon: "square.fill")
                fillButton(.defaultGradient, label: "Gradient", icon: "square.bottomhalf.filled")
            }
        }
    }

    private func fillButton(
        _ style: BackgroundFillStyle,
        label: String,
        icon: String
    ) -> some View {
        let isSelected = backgroundFill == style
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                backgroundFill = style
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Frame Loading

    private func loadSourceFrame() async {
        let url = URL(fileURLWithPath: videoFilePath)
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.maximumSize = CGSize(width: 1920, height: 1080)
        generator.appliesPreferredTrackTransform = true

        do {
            let (cgImage, _) = try await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600))
            let ciImage = CIImage(cgImage: cgImage)
            sourceImage = ciImage
            updatePreview()
        } catch {
            // Preview unavailable — export still works
        }
    }

    private func updatePreview() {
        guard let sourceImage, let preset = selectedPreset else {
            previewCGImage = nil
            return
        }
        previewCGImage = ReframeCompositor.renderPreview(
            from: sourceImage,
            config: ReframeConfig(
                aspectRatio: preset,
                backgroundFill: backgroundFill,
                focusX: focusX,
                focusY: focusY
            ),
            previewWidth: previewWidth
        )
    }
}
