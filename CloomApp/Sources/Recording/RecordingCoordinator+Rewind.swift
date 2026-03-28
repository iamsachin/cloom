import Foundation
import AVFoundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingCoordinator")

// MARK: - Punch-In Rewind

extension RecordingCoordinator {

    func beginRewind() {
        guard case .paused(let startedAt, let pausedAt) = state else { return }

        let totalDuration = segments.reduce(0.0) { $0 + ($1.effectiveDuration ?? $1.duration) }
        guard totalDuration > 0 else {
            logger.warning("Cannot rewind — no segment duration available")
            return
        }

        state = .rewinding(startedAt: startedAt, pausedAt: pausedAt)
        recordingToolbar.dismiss()

        rewindPicker.show(
            totalDuration: totalDuration,
            onConfirm: { [weak self] rewindSeconds in
                self?.confirmRewind(rewindSeconds: rewindSeconds)
            },
            onCancel: { [weak self] in
                self?.cancelRewind()
            }
        )
    }

    func cancelRewind() {
        guard case .rewinding(let startedAt, let pausedAt) = state else { return }

        rewindPicker.dismiss()
        state = .paused(startedAt: startedAt, pausedAt: pausedAt)
        showPausedToolbar(startedAt: startedAt)
    }

    func confirmRewind(rewindSeconds: TimeInterval) {
        guard case .rewinding(let startedAt, let pausedAt) = state else { return }

        rewindPicker.dismiss()

        let totalDuration = segments.reduce(0.0) { $0 + ($1.effectiveDuration ?? $1.duration) }
        let targetTime = max(0, totalDuration - rewindSeconds)

        // Record where the punch-in happens
        punchInMarkers.append(PunchInMarker(timestampMs: Int64(targetTime * 1000)))
        logger.info("Punch-in at \(targetTime)s (rewound \(rewindSeconds)s)")

        truncateSegments(to: targetTime)

        // Update paused duration to account for the discarded time
        let newTotalDuration = segments.reduce(0.0) { $0 + ($1.effectiveDuration ?? $1.duration) }
        let discardedTime = totalDuration - newTotalDuration
        pausedDuration += discardedTime

        state = .paused(startedAt: startedAt, pausedAt: pausedAt)
        resumeRecording()
    }

    // MARK: - Segment Truncation

    /// Mark segments for truncation/removal without re-encoding files.
    /// Sets `effectiveDuration` on the split segment; the stitcher uses partial time ranges.
    func truncateSegments(to targetTime: TimeInterval) {
        var cumulativeTime: TimeInterval = 0

        // Find which segment contains the target time
        var keepCount = 0
        var splitIndex: Int?
        var offsetInSplitSegment: TimeInterval = 0

        for (index, segment) in segments.enumerated() {
            let segmentEnd = cumulativeTime + segment.duration
            if segmentEnd <= targetTime {
                keepCount = index + 1
                cumulativeTime = segmentEnd
            } else {
                splitIndex = index
                offsetInSplitSegment = targetTime - cumulativeTime
                break
            }
        }

        // Delete segment files after the split point
        let removeStart = (splitIndex ?? keepCount) + 1
        if removeStart < segments.count {
            for i in removeStart..<segments.count {
                let seg = segments[i]
                try? FileManager.default.removeItem(at: seg.url)
                logger.info("Deleted segment \(seg.index) (after rewind point)")
            }
            segments.removeSubrange(removeStart..<segments.count)
        }

        // Mark the split segment with an effective duration (no file re-encode)
        if let splitIdx = splitIndex, splitIdx < segments.count {
            if offsetInSplitSegment <= 0 {
                // Target is at the start of this segment — remove it entirely
                try? FileManager.default.removeItem(at: segments[splitIdx].url)
                segments.remove(at: splitIdx)
            } else if offsetInSplitSegment < segments[splitIdx].duration {
                segments[splitIdx].effectiveDuration = offsetInSplitSegment
                let segIdx = segments[splitIdx].index
                logger.info("Marked segment \(segIdx) effective duration: \(offsetInSplitSegment)s")
            }
            // else: offset equals full duration, keep segment as-is
        }

        segmentIndex = segments.count
        let segCount = segments.count
        logger.info("After rewind: \(segCount) segments, target \(targetTime)s")
    }
}
