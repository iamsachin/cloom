import AVFoundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "ThumbnailGenerator")

enum ThumbnailGenerator {
    static func generateThumbnail(
        for videoURL: URL,
        at time: CMTime = CMTime(seconds: 0.5, preferredTimescale: 600),
        maxSize: CGSize = CGSize(width: 640, height: 360)
    ) async -> String? {
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.maximumSize = maxSize
        generator.appliesPreferredTrackTransform = true

        do {
            let (cgImage, _) = try await generator.image(at: time)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
                logger.error("Failed to convert thumbnail to JPEG")
                return nil
            }

            let thumbnailURL = videoURL.deletingPathExtension().appendingPathExtension("jpg")
            try jpegData.write(to: thumbnailURL)
            return thumbnailURL.path
        } catch {
            logger.error("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
}
