import CoreGraphics

enum CaptureMode: Equatable {
    case fullScreen(displayID: CGDirectDisplayID)
    case window(windowID: CGWindowID)
    case region(displayID: CGDirectDisplayID, rect: CGRect)
    case webcamOnly

    /// Default: primary display full-screen capture.
    static var `default`: CaptureMode {
        .fullScreen(displayID: CGMainDisplayID())
    }
}
