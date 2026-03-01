import Testing
import CoreGraphics
@testable import Cloom

// MARK: - Task 163: Capture Math Tests

// MARK: - MicGainProcessor

@Suite("MicGainProcessor")
struct MicGainProcessorTests {

    @Test func sensitivityZeroMuted() {
        let processor = MicGainProcessor(sensitivity: 0)
        #expect(processor.isUnity == false)
    }

    @Test func sensitivityHundredIsUnity() {
        let processor = MicGainProcessor(sensitivity: 100)
        #expect(processor.isUnity == true)
    }

    @Test func sensitivityFiftyNotUnity() {
        let processor = MicGainProcessor(sensitivity: 50)
        #expect(processor.isUnity == false)
    }

    @Test func sensitivityTwoHundredNotUnity() {
        let processor = MicGainProcessor(sensitivity: 200)
        #expect(processor.isUnity == false)
    }

    @Test func negativeSensitivityClampedToZero() {
        let processor = MicGainProcessor(sensitivity: -10)
        #expect(processor.isUnity == false)
    }

    @Test func overThreeHundredClamped() {
        // max(0, min(2, 300/100)) = max(0, min(2, 3.0)) = max(0, 2.0) = 2.0
        let processor = MicGainProcessor(sensitivity: 300)
        #expect(processor.isUnity == false)
    }

    @Test func nearUnityStillUnity() {
        // sensitivity 100 → gain = 1.0 exactly → isUnity should be true
        let processor = MicGainProcessor(sensitivity: 100)
        #expect(processor.isUnity == true)
    }
}

// MARK: - WebcamShape

@Suite("WebcamShape")
struct WebcamShapeTests {

    @Test func circleAspectRatio() {
        #expect(WebcamShape.circle.aspectRatio == 1.0)
    }

    @Test func roundedRectAspectRatio() {
        #expect(WebcamShape.roundedRect.aspectRatio == 1.33)
    }

    @Test func pillAspectRatio() {
        #expect(WebcamShape.pill.aspectRatio == 1.8)
    }

    @Test func circleCornerRadius() {
        #expect(WebcamShape.circle.cornerRadius(forHeight: 100) == 50)
    }

    @Test func roundedRectCornerRadius() {
        #expect(WebcamShape.roundedRect.cornerRadius(forHeight: 100) == 20)
    }

    @Test func pillCornerRadius() {
        #expect(WebcamShape.pill.cornerRadius(forHeight: 100) == 50)
    }

    @Test func cornerRadiusZeroHeight() {
        #expect(WebcamShape.circle.cornerRadius(forHeight: 0) == 0)
    }

    @Test func nextCyclesCorrectly() {
        #expect(WebcamShape.circle.next == .roundedRect)
        #expect(WebcamShape.roundedRect.next == .pill)
        #expect(WebcamShape.pill.next == .circle)
    }

    @Test func displayNames() {
        #expect(WebcamShape.circle.displayName == "Circle")
        #expect(WebcamShape.roundedRect.displayName == "Rounded")
        #expect(WebcamShape.pill.displayName == "Pill")
    }

    @Test func allCasesCount() {
        #expect(WebcamShape.allCases.count == 3)
    }
}
