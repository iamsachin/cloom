import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ThumbnailStripGenerator")

actor ThumbnailStripGenerator {
    func generate(from url: URL, count: Int) async throws -> [(timeMs: Int64, image: CGImage)] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationMs = Int64(duration.seconds * 1000)

        guard durationMs > 0, count > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 120)
        generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)

        let interval = durationMs / Int64(count)
        var results: [(timeMs: Int64, image: CGImage)] = []

        for i in 0..<count {
            let timeMs = Int64(i) * interval + interval / 2
            let cmTime = CMTime(value: CMTimeValue(timeMs), timescale: 1000)

            do {
                let (image, _) = try await generator.image(at: cmTime)
                results.append((timeMs: timeMs, image: image))
            } catch {
                logger.warning("Failed to generate thumbnail at \(timeMs)ms: \(error)")
            }
        }

        logger.info("Generated \(results.count)/\(count) thumbnail strip images")
        return results
    }
}
