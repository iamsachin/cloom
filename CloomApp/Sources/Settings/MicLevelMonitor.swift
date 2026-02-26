import AVFoundation
import Combine

/// Captures real-time mic audio and publishes the peak level (0.0–1.0) after gain.
@MainActor
final class MicLevelMonitor: NSObject, ObservableObject {
    @Published var level: Float = 0

    private var session: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private let queue = DispatchQueue(label: "com.cloom.micLevel", qos: .userInteractive)
    private nonisolated(unsafe) var gainLinear: Float = 1.0
    private nonisolated(unsafe) var rawLevel: Float = 0

    func start(deviceID: String?, sensitivity: Int) {
        stop()

        let session = AVCaptureSession()
        session.sessionPreset = .high

        let mic: AVCaptureDevice?
        if let id = deviceID, !id.isEmpty {
            mic = AVCaptureDevice(uniqueID: id)
        } else {
            mic = AVCaptureDevice.default(for: .audio)
        }
        guard let mic else { return }

        do {
            let input = try AVCaptureDeviceInput(device: mic)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            return
        }

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        self.gainLinear = max(0, min(2, Float(sensitivity) / 100.0))
        self.session = session
        self.audioOutput = output

        session.startRunning()
    }

    func updateSensitivity(_ sensitivity: Int) {
        gainLinear = max(0, min(2, Float(sensitivity) / 100.0))
    }

    func stop() {
        session?.stopRunning()
        session = nil
        audioOutput = nil
        level = 0
    }
}

extension MicLevelMonitor: AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }

        guard asbd.pointee.mFormatID == kAudioFormatLinearPCM,
              asbd.pointee.mBitsPerChannel == 32,
              (asbd.pointee.mFormatFlags & kAudioFormatFlagIsFloat) != 0 else { return }

        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList()

        let result = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        guard result == noErr else { return }

        let buffers = UnsafeMutableAudioBufferListPointer(&audioBufferList)
        var peak: Float = 0
        for buf in buffers {
            guard let data = buf.mData else { continue }
            let count = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
            let samples = data.bindMemory(to: Float.self, capacity: count)
            for i in 0..<count {
                let v = abs(samples[i])
                if v > peak { peak = v }
            }
        }

        let gained = min(1.0, peak * gainLinear)
        // Smooth: fast attack, slow decay
        let current = rawLevel
        let smoothed = gained > current ? gained : current * 0.85 + gained * 0.15
        rawLevel = smoothed

        Task { @MainActor [smoothed] in
            self.level = smoothed
        }
    }
}
