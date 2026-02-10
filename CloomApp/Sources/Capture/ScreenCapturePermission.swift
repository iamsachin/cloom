import CoreGraphics

enum ScreenCapturePermission {
    static func hasAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
