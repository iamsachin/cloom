import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "PersonSegmenter")

final class PersonSegmenter {
    var isEnabled: Bool = false

    private let sequenceHandler = VNSequenceRequestHandler()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let blurRadius: Double = 20.0
    private let maskSoftenSigma: Double = 2.5

    func process(image: CIImage, pixelBuffer: CVPixelBuffer) -> CIImage {
        guard isEnabled else { return image }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced

        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            logger.error("Person segmentation failed: \(error)")
            return image
        }

        guard let observation = request.results?.first else {
            return image
        }

        let maskBuffer = observation.pixelBuffer
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)

        let scaleX = image.extent.width / maskImage.extent.width
        let scaleY = image.extent.height / maskImage.extent.height
        let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let softenedMask = scaledMask.applyingGaussianBlur(sigma: maskSoftenSigma)
            .cropped(to: image.extent)

        let blurredBackground = image.applyingGaussianBlur(sigma: blurRadius)
            .cropped(to: image.extent)

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = image
        blendFilter.backgroundImage = blurredBackground
        blendFilter.maskImage = softenedMask

        return blendFilter.outputImage ?? image
    }
}
