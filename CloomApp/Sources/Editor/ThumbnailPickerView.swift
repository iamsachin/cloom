import SwiftUI
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ThumbnailPicker")

struct ThumbnailPickerView: View {
    let editorState: EditorState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimeMs: Int64 = 500
    @State private var previewImage: CGImage?
    @State private var isGenerating = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Thumbnail")
                .font(.headline)

            // Preview image
            if let previewImage {
                Image(previewImage, scale: 1.0, label: Text("Thumbnail"))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.controlBackgroundColor))
                    .frame(height: 200)
                    .overlay {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                        }
                    }
            }

            // Time slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { Double(selectedTimeMs) },
                        set: { selectedTimeMs = Int64($0) }
                    ),
                    in: 0...Double(max(1, editorState.durationMs)),
                    step: 100
                )

                Text(formatTime(ms: selectedTimeMs))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .onChange(of: selectedTimeMs) {
                generatePreview()
            }

            HStack {
                Button("Use Current Frame") {
                    selectedTimeMs = editorState.currentTimeMs
                    generatePreview()
                }

                Button("Reset") {
                    selectedTimeMs = 500
                    generatePreview()
                }

                Spacer()

                Button("Cancel") { dismiss() }

                Button("Apply") {
                    applyThumbnail()
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(24)
        .frame(width: 450)
        .onAppear {
            selectedTimeMs = editorState.edl.thumbnailTimeMs
            generatePreview()
        }
    }

    private func generatePreview() {
        isGenerating = true
        let url = URL(fileURLWithPath: editorState.videoRecord.filePath)
        let time = CMTime(value: CMTimeValue(selectedTimeMs), timescale: 1000)

        Task {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 480)

            do {
                let (image, _) = try await generator.image(at: time)
                previewImage = image
            } catch {
                logger.warning("Failed to generate preview: \(error)")
            }
            isGenerating = false
        }
    }

    private func applyThumbnail() {
        editorState.setThumbnailTime(ms: selectedTimeMs)

        // Generate and save thumbnail PNG
        let url = URL(fileURLWithPath: editorState.videoRecord.filePath)
        let time = CMTime(value: CMTimeValue(selectedTimeMs), timescale: 1000)

        Task {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 480)

            do {
                let (image, _) = try await generator.image(at: time)
                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    let thumbPath = editorState.videoRecord.thumbnailPath
                    if !thumbPath.isEmpty {
                        try pngData.write(to: URL(fileURLWithPath: thumbPath))
                        logger.info("Saved custom thumbnail at \(selectedTimeMs)ms")
                    }
                }
            } catch {
                logger.error("Failed to save thumbnail: \(error)")
            }
            dismiss()
        }
    }

    private func formatTime(ms: Int64) -> String {
        let totalSeconds = Int(ms / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
