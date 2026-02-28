import AVFoundation
import ImageIO
import UniformTypeIdentifiers
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
        // Allow tolerance for faster keyframe-based extraction (exact decode unnecessary for GIF)
        let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        // Extract frames in parallel with a sliding window of 8 concurrent tasks
        let manifestLines = try await extractFramesParallel(
            generator: generator,
            frameCount: frameCount,
            fps: fps,
            tempDir: tempDir,
            progress: progress
        )

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

    // MARK: - Parallel Frame Extraction

    private struct FrameResult: Sendable {
        let index: Int
        let timeMs: Int
        let path: String
    }

    /// Sendable wrapper for AVAssetImageGenerator (thread-safe for image(at:) calls).
    private final class SendableGenerator: @unchecked Sendable {
        let generator: AVAssetImageGenerator
        init(_ generator: AVAssetImageGenerator) { self.generator = generator }
    }

    /// Extract frames using a sliding window of concurrent tasks for throughput.
    private func extractFramesParallel(
        generator: AVAssetImageGenerator,
        frameCount: Int,
        fps: Int,
        tempDir: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [String] {
        let windowSize = 8
        let gen = SendableGenerator(generator)

        let results = try await withThrowingTaskGroup(of: FrameResult?.self) { group in
            var nextIndex = 0
            var completed = 0
            var collected: [FrameResult] = []

            // Seed initial window
            while nextIndex < min(windowSize, frameCount) {
                let i = nextIndex
                let dir = tempDir
                group.addTask {
                    try await Self.extractSingleFrame(
                        generator: gen, index: i, fps: fps, tempDir: dir
                    )
                }
                nextIndex += 1
            }

            // Sliding window: as each completes, add the next
            for try await result in group {
                completed += 1
                if let r = result { collected.append(r) }
                progress(0.5 * Double(completed) / Double(frameCount))

                if nextIndex < frameCount {
                    let i = nextIndex
                    let dir = tempDir
                    group.addTask {
                        try await Self.extractSingleFrame(
                            generator: gen, index: i, fps: fps, tempDir: dir
                        )
                    }
                    nextIndex += 1
                }
            }

            return collected.sorted { $0.index < $1.index }
        }

        return results.map { "\($0.timeMs)\t\($0.path)" }
    }

    private static func extractSingleFrame(
        generator: SendableGenerator,
        index: Int,
        fps: Int,
        tempDir: URL
    ) async throws -> FrameResult? {
        let timeSeconds = Double(index) / Double(fps)
        let cmTime = CMTime(seconds: timeSeconds, preferredTimescale: 600)

        do {
            let (image, _) = try await generator.generator.image(at: cmTime)
            let framePath = tempDir.appendingPathComponent(String(format: "frame_%05d.png", index))

            if let dest = CGImageDestinationCreateWithURL(
                framePath as CFURL, UTType.png.identifier as CFString, 1, nil
            ) {
                CGImageDestinationAddImage(dest, image, nil)
                if CGImageDestinationFinalize(dest) {
                    return FrameResult(
                        index: index,
                        timeMs: Int(timeSeconds * 1000),
                        path: framePath.path
                    )
                }
            }
        } catch {
            logger.warning("Failed to extract frame \(index): \(error)")
        }
        return nil
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
