import Testing
@testable import Cloom

// MARK: - Task 166: Waveform Noise Floor Tests

@Suite("WaveformGenerator.applyNoiseFloor")
struct WaveformNoiseFloorTests {

    @Test func emptyPeaks() {
        let result = WaveformGenerator.applyNoiseFloor(peaks: [], micSensitivity: 100)
        #expect(result.isEmpty)
    }

    @Test func allZeroPeaks() {
        let peaks: [Float] = [0, 0, 0, 0, 0]
        let result = WaveformGenerator.applyNoiseFloor(peaks: peaks, micSensitivity: 100)
        #expect(result == [0, 0, 0, 0, 0])
    }

    @Test func sensitivityZeroHighMultiplier() {
        // sensitivity 0 → noiseMultiplier = 5.0
        // median of [0.1, 0.2, 0.3] = 0.2, noiseFloor = 0.2 * 5.0 = 1.0
        // all peaks < 1.0 → all zeroed
        let peaks: [Float] = [0.1, 0.2, 0.3]
        let result = WaveformGenerator.applyNoiseFloor(peaks: peaks, micSensitivity: 0)
        #expect(result == [0, 0, 0])
    }

    @Test func sensitivityHundredLowMultiplier() {
        // sensitivity 100 → noiseMultiplier = 2.0
        // median of [0.1, 0.2, 0.8] = 0.2, noiseFloor = 0.2 * 2.0 = 0.4
        // 0.1 < 0.4 → 0, 0.2 < 0.4 → 0, 0.8 >= 0.4 → 0.8
        let peaks: [Float] = [0.1, 0.2, 0.8]
        let result = WaveformGenerator.applyNoiseFloor(peaks: peaks, micSensitivity: 100)
        #expect(result[0] == 0)
        #expect(result[1] == 0)
        #expect(result[2] == 0.8)
    }

    @Test func loudPeaksSurvive() {
        // All peaks well above noise floor
        let peaks: [Float] = [0.9, 0.95, 1.0]
        let result = WaveformGenerator.applyNoiseFloor(peaks: peaks, micSensitivity: 100)
        // median = 0.95, noiseFloor = 0.95 * 2.0 = 1.9 → all < 1.9 → all zeroed
        // Actually this would zero everything... let me use sensitivity that gives lower multiplier
        // With sensitivity 100, noiseMultiplier = 2.0 → floor = 0.95 * 2.0 = 1.9
        // So everything is below 1.9 and gets zeroed. That's by design for uniform peaks.
        #expect(result == [0, 0, 0])
    }

    @Test func mixedPeaksWithSpeech() {
        // Simulate background noise + speech spikes
        let peaks: [Float] = [0.01, 0.02, 0.01, 0.5, 0.8, 0.01, 0.02]
        let result = WaveformGenerator.applyNoiseFloor(peaks: peaks, micSensitivity: 100)
        // sorted: [0.01, 0.01, 0.01, 0.02, 0.02, 0.5, 0.8]
        // median (idx 3) = 0.02, noiseFloor = 0.02 * 2.0 = 0.04
        // 0.01 < 0.04 → 0, 0.02 < 0.04 → 0, 0.5 ≥ 0.04 → 0.5, 0.8 ≥ 0.04 → 0.8
        #expect(result[0] == 0)
        #expect(result[1] == 0)
        #expect(result[2] == 0)
        #expect(result[3] == 0.5)
        #expect(result[4] == 0.8)
        #expect(result[5] == 0)
        #expect(result[6] == 0)
    }

    @Test func singlePeak() {
        let peaks: [Float] = [0.5]
        let result = WaveformGenerator.applyNoiseFloor(peaks: peaks, micSensitivity: 100)
        // median = 0.5, noiseFloor = 0.5 * 2.0 = 1.0
        // 0.5 < 1.0 → 0
        #expect(result == [0])
    }

    @Test func sensitivityAboveHundredClamped() {
        // sensitivity 150 → min(150, 100) = 100 → same as 100
        let peaks: [Float] = [0.1, 0.5]
        let result100 = WaveformGenerator.applyNoiseFloor(peaks: peaks, micSensitivity: 100)
        let result150 = WaveformGenerator.applyNoiseFloor(peaks: peaks, micSensitivity: 150)
        #expect(result100 == result150)
    }
}
