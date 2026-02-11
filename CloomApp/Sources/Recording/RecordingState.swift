import Foundation

enum RecordingState: Equatable {
    case idle
    case selectingContent
    case countdown(Int)
    case recording(startedAt: Date)
    case paused(startedAt: Date, pausedAt: Date)
    case stopping

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isActiveOrPaused: Bool {
        isRecording || isPaused
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
