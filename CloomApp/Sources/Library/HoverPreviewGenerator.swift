import AVFoundation
import CoreGraphics
import Foundation

actor HoverPreviewGenerator {
    static let shared = HoverPreviewGenerator()

    private let cache = NSCache<NSString, NSArray>()
    private let frameCount = 8
    private let maxSize = CGSize(width: 400, height: 225)

    private init() {
        cache.countLimit = 30
        cache.totalCostLimit = 50_000_000
    }

    func previewFrames(for filePath: String) async throws -> [CGImage] {
        let key = filePath as NSString
        if let cached = cache.object(forKey: key) as? [CGImage] {
            return cached
        }

        let url = URL(fileURLWithPath: filePath)
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize

        var frames: [CGImage] = []
        frames.reserveCapacity(frameCount)

        for i in 0..<frameCount {
            try Task.checkCancellation()
            let fraction = Double(i) / Double(frameCount)
            let time = CMTime(seconds: fraction * durationSeconds, preferredTimescale: 600)
            let (image, _) = try await generator.image(at: time)
            frames.append(image)
        }

        cache.setObject(frames as NSArray, forKey: key)
        return frames
    }
}
