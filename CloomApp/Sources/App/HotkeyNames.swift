import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.r, modifiers: [.command, .shift]))
    static let togglePause = Self("togglePause", default: .init(.p, modifiers: [.command, .shift]))
    static let toggleTeleprompterScroll = Self("toggleTeleprompterScroll", default: .init(.t, modifiers: [.command, .shift]))
}
