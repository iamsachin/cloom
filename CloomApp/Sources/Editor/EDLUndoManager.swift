import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.cloom.app", category: "EDLUndoManager")

/// Captures the mutable state of an EditDecisionList for undo/redo.
struct EDLState: Equatable {
    let trimStartMs: Int64
    let trimEndMs: Int64
    let cutsJSON: String
    let stitchVideoIDsJSON: String
    let speedMultiplier: Double
    let thumbnailTimeMs: Int64

    init(from edl: EditDecisionList) {
        self.trimStartMs = edl.trimStartMs
        self.trimEndMs = edl.trimEndMs
        self.cutsJSON = edl.cutsJSON
        self.stitchVideoIDsJSON = edl.stitchVideoIDsJSON
        self.speedMultiplier = edl.speedMultiplier
        self.thumbnailTimeMs = edl.thumbnailTimeMs
    }

    func apply(to edl: EditDecisionList) {
        edl.trimStartMs = trimStartMs
        edl.trimEndMs = trimEndMs
        edl.cutsJSON = cutsJSON
        edl.stitchVideoIDsJSON = stitchVideoIDsJSON
        edl.speedMultiplier = speedMultiplier
        edl.thumbnailTimeMs = thumbnailTimeMs
        edl.updatedAt = .now
    }
}

/// In-memory undo/redo stack for EDL operations.
@MainActor
final class EDLUndoManager {
    private var undoStack: [EDLState] = []
    private var redoStack: [EDLState] = []
    private let maxHistory = 50

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Call before making a mutation to capture the current state.
    func recordState(_ edl: EditDecisionList) {
        let state = EDLState(from: edl)
        undoStack.append(state)
        if undoStack.count > maxHistory {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    /// Undo the last operation, returning the state to restore.
    func undo(current edl: EditDecisionList) -> Bool {
        guard let previous = undoStack.popLast() else { return false }
        // Save current state to redo stack
        redoStack.append(EDLState(from: edl))
        previous.apply(to: edl)
        logger.info("Undo applied — \(self.undoStack.count) remaining")
        return true
    }

    /// Redo the last undone operation.
    func redo(current edl: EditDecisionList) -> Bool {
        guard let next = redoStack.popLast() else { return false }
        // Save current state to undo stack
        undoStack.append(EDLState(from: edl))
        next.apply(to: edl)
        logger.info("Redo applied — \(self.redoStack.count) remaining")
        return true
    }

    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
