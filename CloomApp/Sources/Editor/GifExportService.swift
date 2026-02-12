import AVFoundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "GifExportService")

actor GifExportService {
    enum GifError: LocalizedError {
        case noFrames
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noFrames: "No frames extracted for GIF"
            case .exportFailed(let msg): "GIF export failed: \(msg)"
            }
        }
    }

    func export(
        sourceURL: URL,
        edl: EDLSnapshot,
        outputURL: URL,
        width: Int,
        fps: Int,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        // 1. Build composition with edits applied
        let builder = EditorCompositionBuilder()
        let result = try await builder.build(edl: edl, sourceURL: sourceURL, stitchURLs: [])

        // 2. Extract frames as PNGs to temp dir
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloom-gif-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let asset = result.composition
        let duration = result.duration
        let totalSeconds = duration.seconds
        let frameCount = Int(totalSeconds * Double(fps))

        guard frameCount > 0 else { throw GifError.noFrames }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: width, height: 0) // maintain aspect ratio
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var manifestLines: [String] = []

        for i in 0..<frameCount {
            let timeSeconds = Double(i) / Double(fps)
            let cmTime = CMTime(seconds: timeSeconds, preferredTimescale: 600)

            do {
                let (image, _) = try await generator.image(at: cmTime)
                let framePath = tempDir.appendingPathComponent(String(format: "frame_%05d.png", i))

                let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                if let tiffData = nsImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try pngData.write(to: framePath)
                    manifestLines.append("\(Int(timeSeconds * 1000))\t\(framePath.path)")
                }
            } catch {
                logger.warning("Failed to extract frame \(i): \(error)")
            }

            progress(0.5 * Double(i + 1) / Double(frameCount))
        }

        guard !manifestLines.isEmpty else { throw GifError.noFrames }

        // 3. Write manifest
        let manifestPath = tempDir.appendingPathComponent("manifest.txt")
        try manifestLines.joined(separator: "\n").write(to: manifestPath, atomically: true, encoding: .utf8)

        // 4. Call Rust gifski export
        let config = GifConfig(
            width: UInt32(width),
            height: 0, // auto from aspect ratio
            fps: UInt8(fps),
            quality: 90,
            repeatCount: 0 // loop forever
        )

        let callbackAdapter = GifProgressAdapter(callback: { p in
            progress(0.5 + 0.5 * Double(p))
        })

        let resultPath = try exportGif(
            manifestPath: manifestPath.path,
            outputPath: outputURL.path,
            config: config,
            progress: callbackAdapter
        )

        logger.info("GIF exported to \(resultPath)")
    }
}

// MARK: - Callback Adapter

final class GifProgressAdapter: GifProgressCallback, @unchecked Sendable {
    private let callback: (Float) -> Void

    init(callback: @escaping (Float) -> Void) {
        self.callback = callback
    }

    func onProgress(fraction: Float) {
        callback(fraction)
    }
}
