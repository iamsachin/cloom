import AppKit

extension NSScreen {
    /// Find the screen matching a given `CGDirectDisplayID`.
    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { screen in
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            return (screen.deviceDescription[key] as? CGDirectDisplayID) == displayID
        }
    }
}
