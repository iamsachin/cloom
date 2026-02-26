import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "PersonSegmenter")

final class PersonSegmenter {
    var isEnabled: Bool = false

    private let sequenceHandler = VNSequenceRequestHandler()
    private let ciContext = SharedCIContext.instance
    private let blurRadius: Double = 20.0
    private let maskSoftenSigma: Double = 2.5

    /// Run Vision every Nth frame (~6fps at 30fps capture) to reduce CPU/ANE load.
    private let segmentationInterval = 5
    private var frameCounter = 0
    private var cachedMask: CIImage?

    func process(image: CIImage, pixelBuffer: CVPixelBuffer) -> CIImage {
        guard isEnabled else { return image }

        frameCounter += 1

        // Only run Vision on every Nth frame; reuse cached mask otherwise.
        if frameCounter % segmentationInterval == 1 || cachedMask == nil {
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .balanced

            do {
                try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
            } catch {
                logger.error("Person segmentation failed: \(error)")
                return image
            }

            if let observation = request.results?.first {
                let maskBuffer = observation.pixelBuffer
                let maskImage = CIImage(cvPixelBuffer: maskBuffer)

                let scaleX = image.extent.width / maskImage.extent.width
                let scaleY = image.extent.height / maskImage.extent.height
                let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                cachedMask = scaledMask.applyingGaussianBlur(sigma: maskSoftenSigma)
                    .cropped(to: image.extent)
            }
        }

        guard let softenedMask = cachedMask?.cropped(to: image.extent) else { return image }

        let blurredBackground = image.applyingGaussianBlur(sigma: blurRadius)
            .cropped(to: image.extent)

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = image
        blendFilter.backgroundImage = blurredBackground
        blendFilter.maskImage = softenedMask

        return blendFilter.outputImage ?? image
    }
}
