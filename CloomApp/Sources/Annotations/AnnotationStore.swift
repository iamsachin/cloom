import CoreGraphics
import Foundation
import os

/// Thread-safe shared state for annotations, following the same OSAllocatedUnfairLock pattern as WebcamCompositor.
final class AnnotationStore: @unchecked Sendable {
    private struct State: Sendable {
        var strokes: [AnnotationStroke] = []
        var activeStroke: AnnotationStroke? = nil
        var ripples: [ClickRipple] = []
        var spotlight: SpotlightState = SpotlightState()
    }

    private let state: OSAllocatedUnfairLock<State>

    init() {
        self.state = OSAllocatedUnfairLock(initialState: State())
    }

    // MARK: - Strokes

    func addStroke(_ stroke: AnnotationStroke) {
        state.withLock { state in
            state.activeStroke = nil
            state.strokes.append(stroke)
        }
    }

    func setActiveStroke(_ stroke: AnnotationStroke) {
        state.withLock { $0.activeStroke = stroke }
    }

    func clearActiveStroke() {
        state.withLock { $0.activeStroke = nil }
    }

    func undo() {
        state.withLock { state in
            if !state.strokes.isEmpty {
                state.strokes.removeLast()
            }
        }
    }

    func eraseStrokes(intersecting rect: CGRect) {
        state.withLock { state in
            state.strokes.removeAll { stroke in
                stroke.points.contains { point in
                    rect.contains(point.cgPoint)
                }
            }
        }
    }

    func clearAll() {
        state.withLock { state in
            state.strokes.removeAll()
        }
    }

    // MARK: - Ripples

    func addRipple(_ ripple: ClickRipple) {
        state.withLock { $0.ripples.append(ripple) }
    }

    func pruneExpiredRipples(currentTime: TimeInterval) {
        state.withLock { state in
            state.ripples.removeAll { ripple in
                currentTime - ripple.startTime > ripple.duration
            }
        }
    }

    // MARK: - Spotlight

    func updateSpotlight(normalizedX: CGFloat, normalizedY: CGFloat) {
        state.withLock { state in
            state.spotlight.normalizedX = normalizedX
            state.spotlight.normalizedY = normalizedY
        }
    }

    func setSpotlightEnabled(_ enabled: Bool) {
        state.withLock { $0.spotlight.isEnabled = enabled }
    }

    // MARK: - Snapshot

    func snapshot() -> AnnotationSnapshot {
        state.withLock { state in
            var allStrokes = state.strokes
            if let active = state.activeStroke {
                allStrokes.append(active)
            }
            return AnnotationSnapshot(
                strokes: allStrokes,
                ripples: state.ripples,
                spotlight: state.spotlight
            )
        }
    }
}
