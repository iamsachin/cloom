import Foundation
import AppKit
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "GlobalHotkeyManager")

// MARK: - Hotkey Binding

struct HotkeyBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64 // CGEventFlags rawValue

    var displayString: String {
        var parts: [String] = []
        let flags = CGEventFlags(rawValue: modifiers)
        if flags.contains(.maskControl) { parts.append("⌃") }
        if flags.contains(.maskAlternate) { parts.append("⌥") }
        if flags.contains(.maskShift) { parts.append("⇧") }
        if flags.contains(.maskCommand) { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
}

// MARK: - Hotkey Action

enum HotkeyAction: String, CaseIterable, Codable {
    case toggleRecording
    case togglePause
}

// MARK: - Global Hotkey Manager

@MainActor
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()

    var onToggleRecording: (() -> Void)?
    var onTogglePause: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var bindings: [HotkeyAction: HotkeyBinding] = [:]

    private init() {
        loadBindings()
    }

    // MARK: - Default Bindings

    static let defaultBindings: [HotkeyAction: HotkeyBinding] = [
        // Cmd+Shift+R
        .toggleRecording: HotkeyBinding(
            keyCode: UInt16(kVK_ANSI_R),
            modifiers: CGEventFlags([.maskCommand, .maskShift]).rawValue
        ),
        // Cmd+Shift+P
        .togglePause: HotkeyBinding(
            keyCode: UInt16(kVK_ANSI_P),
            modifiers: CGEventFlags([.maskCommand, .maskShift]).rawValue
        ),
    ]

    // MARK: - Persistence

    private func loadBindings() {
        if let data = UserDefaults.standard.data(forKey: "globalHotkeyBindings"),
           let decoded = try? JSONDecoder().decode([HotkeyAction: HotkeyBinding].self, from: data) {
            bindings = decoded
        } else {
            bindings = Self.defaultBindings
        }
    }

    private func saveBindings() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: "globalHotkeyBindings")
        }
    }

    func updateBinding(action: HotkeyAction, binding: HotkeyBinding) {
        bindings[action] = binding
        saveBindings()
    }

    func resetToDefaults() {
        bindings = Self.defaultBindings
        saveBindings()
    }

    // MARK: - Start / Stop

    func start() {
        guard eventTap == nil else { return }

        // Store self pointer for C callback
        let this = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, _, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let mgr = Unmanaged<GlobalHotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                let flags = event.flags.intersection([.maskCommand, .maskShift, .maskControl, .maskAlternate])

                for (action, binding) in mgr.bindings {
                    if keyCode == binding.keyCode && flags.rawValue == binding.modifiers {
                        DispatchQueue.main.async {
                            switch action {
                            case .toggleRecording:
                                mgr.onToggleRecording?()
                            case .togglePause:
                                mgr.onTogglePause?()
                            }
                        }
                        // Consume the event
                        return nil
                    }
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: this
        )

        guard let tap else {
            logger.warning("Failed to create event tap — Accessibility permission may be missing")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("Global hotkey event tap started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            // CFMachPort doesn't need explicit close — it's invalidated when source is removed
        }
        eventTap = nil
        runLoopSource = nil
        logger.info("Global hotkey event tap stopped")
    }
}

// MARK: - Key Code to String

private func keyCodeToString(_ keyCode: UInt16) -> String {
    // Use TISCopyCurrentKeyboardLayoutInputSource + UCKeyTranslate
    guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
          let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
        return specialKeyName(keyCode) ?? "Key\(keyCode)"
    }

    let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
    guard let keyLayoutPtr = CFDataGetBytePtr(layoutData) else {
        return specialKeyName(keyCode) ?? "Key\(keyCode)"
    }

    var deadKeyState: UInt32 = 0
    var chars = [UniChar](repeating: 0, count: 4)
    var length: Int = 0

    let status = UCKeyTranslate(
        keyLayoutPtr.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 },
        keyCode,
        UInt16(kUCKeyActionDisplay),
        0,
        UInt32(LMGetKbdType()),
        UInt32(kUCKeyTranslateNoDeadKeysBit),
        &deadKeyState,
        chars.count,
        &length,
        &chars
    )

    if status == noErr, length > 0 {
        return String(utf16CodeUnits: chars, count: length).uppercased()
    }

    return specialKeyName(keyCode) ?? "Key\(keyCode)"
}

private func specialKeyName(_ keyCode: UInt16) -> String? {
    switch Int(keyCode) {
    case kVK_Return: return "↩"
    case kVK_Tab: return "⇥"
    case kVK_Space: return "Space"
    case kVK_Delete: return "⌫"
    case kVK_Escape: return "⎋"
    case kVK_ForwardDelete: return "⌦"
    case kVK_LeftArrow: return "←"
    case kVK_RightArrow: return "→"
    case kVK_UpArrow: return "↑"
    case kVK_DownArrow: return "↓"
    case kVK_F1: return "F1"
    case kVK_F2: return "F2"
    case kVK_F3: return "F3"
    case kVK_F4: return "F4"
    case kVK_F5: return "F5"
    case kVK_F6: return "F6"
    case kVK_F7: return "F7"
    case kVK_F8: return "F8"
    case kVK_F9: return "F9"
    case kVK_F10: return "F10"
    case kVK_F11: return "F11"
    case kVK_F12: return "F12"
    default: return nil
    }
}
