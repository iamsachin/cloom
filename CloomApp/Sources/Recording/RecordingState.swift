import Foundation

enum RecordingState: Equatable {
    case idle
    case selectingContent
    case ready
    case countdown(Int)
    case recording(startedAt: Date)
    case paused(startedAt: Date, pausedAt: Date)
    case rewinding(startedAt: Date, pausedAt: Date)
    case stopping

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isRewinding: Bool {
        if case .rewinding = self { return true }
        return false
    }

    var isActiveOrPaused: Bool {
        isRecording || isPaused || isRewinding
    }

    var isIdle: Bool {
        self == .idle
    }

    var isReady: Bool {
        self == .ready
    }

    var isSelectingContent: Bool {
        self == .selectingContent
    }

    var isBusy: Bool {
        !isIdle
    }
}
