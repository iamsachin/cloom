import Foundation
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "RecordingMetrics")

/// Lightweight instrumentation for long recording sessions.
/// Tracks frame/drop counts, segments, elapsed time, and peak memory.
/// Thread-safe via `OSAllocatedUnfairLock`.
final class RecordingMetrics: @unchecked Sendable {
    private struct State {
        var frameCount: Int64 = 0
        var dropCount: Int64 = 0
        var segmentCount: Int = 1
        var startTime: Date?
        var peakMemoryBytes: UInt64 = 0
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private var periodicTimer: Timer?

    /// Call when recording starts.
    @MainActor
    func start() {
        state.withLock { $0.startTime = Date() }
        // Log summary every 60 seconds
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.logPeriodicSummary()
        }
    }

    /// Call when recording stops. Logs final summary.
    @MainActor
    func stop() {
        periodicTimer?.invalidate()
        periodicTimer = nil
        logFinalSummary()
    }

    /// Report a video frame was written.
    nonisolated func reportFrame() {
        state.withLock { $0.frameCount += 1 }
    }

    /// Report a video frame was dropped.
    nonisolated func reportDrop() {
        state.withLock { $0.dropCount += 1 }
    }

    /// Report a new segment was started (pause/resume).
    nonisolated func reportSegment() {
        state.withLock { $0.segmentCount += 1 }
    }

    // MARK: - Private

    private func logPeriodicSummary() {
        let snapshot = state.withLock { s -> (Int64, Int64, Int, Date?, UInt64) in
            (s.frameCount, s.dropCount, s.segmentCount, s.startTime, s.peakMemoryBytes)
        }
        let memBytes = currentMemoryUsage()
        state.withLock { s in
            if memBytes > s.peakMemoryBytes { s.peakMemoryBytes = memBytes }
        }

        let elapsed = snapshot.3.map { Date().timeIntervalSince($0) } ?? 0
        let total = snapshot.0 + snapshot.1
        let dropRate = total > 0 ? Double(snapshot.1) / Double(total) * 100.0 : 0
        let memMB = Double(memBytes) / (1024 * 1024)

        logger.info("""
            Recording metrics — \(String(format: "%.0f", elapsed))s elapsed, \
            \(snapshot.0) frames, \(snapshot.1) drops (\(String(format: "%.1f", dropRate))%), \
            \(snapshot.2) segment(s), \(String(format: "%.1f", memMB))MB memory
            """)
    }

    private func logFinalSummary() {
        let memBytes = currentMemoryUsage()
        let snapshot = state.withLock { s -> (Int64, Int64, Int, Date?, UInt64) in
            if memBytes > s.peakMemoryBytes { s.peakMemoryBytes = memBytes }
            return (s.frameCount, s.dropCount, s.segmentCount, s.startTime, s.peakMemoryBytes)
        }

        let elapsed = snapshot.3.map { Date().timeIntervalSince($0) } ?? 0
        let total = snapshot.0 + snapshot.1
        let dropRate = total > 0 ? Double(snapshot.1) / Double(total) * 100.0 : 0
        let peakMB = Double(snapshot.4) / (1024 * 1024)

        logger.info("""
            Recording FINAL — \(String(format: "%.0f", elapsed))s total, \
            \(snapshot.0) frames, \(snapshot.1) drops (\(String(format: "%.1f", dropRate))%), \
            \(snapshot.2) segment(s), peak memory \(String(format: "%.1f", peakMB))MB
            """)
    }

    private func currentMemoryUsage() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
    }
}
