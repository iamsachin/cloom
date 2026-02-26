import CoreImage

/// Single shared CIContext backed by the default Metal device.
/// CIContext is documented as thread-safe — sharing avoids duplicate GPU command queues.
enum SharedCIContext {
    static let instance: CIContext = {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [.workingColorSpace: colorSpace])
        }
        return CIContext(options: [.workingColorSpace: colorSpace])
    }()
}
