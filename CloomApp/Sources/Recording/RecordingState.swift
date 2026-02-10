import Foundation

enum RecordingState: Equatable {
    case idle
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

    var isBusy: Bool {
        !isIdle
    }
}
