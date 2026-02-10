import Foundation

enum RecordingState: Equatable {
    case idle
    case selectingContent
    case countdown(Int)
    case recording(startedAt: Date)
    case stopping

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isIdle: Bool {
        self == .idle
    }

    var isSelectingContent: Bool {
        self == .selectingContent
    }

    var isBusy: Bool {
        !isIdle
    }
}
