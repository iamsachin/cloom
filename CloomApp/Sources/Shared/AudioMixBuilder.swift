import AVFoundation

extension AVMutableAudioMix {
    /// Build an audio mix that blends all given tracks at full volume (stereo mixdown).
    static func stereoMix(from tracks: [AVMutableCompositionTrack]) -> AVMutableAudioMix {
        let mix = AVMutableAudioMix()
        mix.inputParameters = tracks.map { track in
            let params = AVMutableAudioMixInputParameters(track: track)
            params.setVolume(1.0, at: .zero)
            return params
        }
        return mix
    }
}
