use crate::CloomError;
use symphonia::core::audio::SampleBuffer;
use symphonia::core::codecs::DecoderOptions;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;

/// A time range in milliseconds.
#[derive(Debug, Clone, uniffi::Record)]
pub struct TimeRange {
    pub start_ms: i64,
    pub end_ms: i64,
}

/// Detect silent regions in an audio file.
///
/// Decodes the audio, computes RMS per 10ms window, and identifies
/// contiguous regions below `threshold_db` that last at least `min_duration_ms`.
#[uniffi::export]
pub fn detect_silence(
    audio_path: String,
    threshold_db: f32,
    min_duration_ms: u64,
) -> Result<Vec<TimeRange>, CloomError> {
    let file = std::fs::File::open(&audio_path).map_err(|e| CloomError::IoError {
        msg: format!("Cannot open audio file: {e}"),
    })?;

    let mss = MediaSourceStream::new(Box::new(file), Default::default());

    let mut hint = Hint::new();
    if audio_path.ends_with(".mp4") || audio_path.ends_with(".m4a") {
        hint.with_extension("mp4");
    }

    let probed = symphonia::default::get_probe()
        .format(
            &hint,
            mss,
            &FormatOptions::default(),
            &MetadataOptions::default(),
        )
        .map_err(|e| CloomError::AudioError {
            msg: format!("Failed to probe audio format: {e}"),
        })?;

    let mut format = probed.format;

    // Find the first audio track
    let track = format
        .tracks()
        .iter()
        .find(|t| t.codec_params.codec != symphonia::core::codecs::CODEC_TYPE_NULL)
        .ok_or_else(|| CloomError::AudioError {
            msg: "No audio track found".to_string(),
        })?;

    let sample_rate = track
        .codec_params
        .sample_rate
        .ok_or_else(|| CloomError::AudioError {
            msg: "Unknown sample rate".to_string(),
        })?;

    let track_id = track.id;

    let mut decoder = symphonia::default::get_codecs()
        .make(&track.codec_params, &DecoderOptions::default())
        .map_err(|e| CloomError::AudioError {
            msg: format!("Failed to create decoder: {e}"),
        })?;

    // Collect all decoded samples (mono-mixed) — pre-allocate from estimated duration
    let estimated_samples = sample_rate as usize * 120; // ~2 min estimate
    let mut all_samples: Vec<f32> = Vec::with_capacity(estimated_samples);

    loop {
        let packet = match format.next_packet() {
            Ok(p) => p,
            Err(symphonia::core::errors::Error::IoError(ref e))
                if e.kind() == std::io::ErrorKind::UnexpectedEof =>
            {
                break;
            }
            Err(_) => break,
        };

        if packet.track_id() != track_id {
            continue;
        }

        let decoded = match decoder.decode(&packet) {
            Ok(d) => d,
            Err(e) => {
                log::warn!("Skipping packet: decode error: {e}");
                continue;
            }
        };

        let spec = *decoded.spec();
        let num_channels = spec.channels.count();
        let num_frames = decoded.frames();

        let mut sample_buf = SampleBuffer::<f32>::new(num_frames as u64, spec);
        sample_buf.copy_interleaved_ref(decoded);

        let samples = sample_buf.samples();

        // Mix to mono by averaging channels
        for frame in 0..num_frames {
            let mut sum = 0.0f32;
            for ch in 0..num_channels {
                sum += samples[frame * num_channels + ch];
            }
            all_samples.push(sum / num_channels as f32);
        }
    }

    if all_samples.is_empty() {
        return Ok(Vec::new());
    }

    // Compute RMS per 10ms window
    let window_samples = (sample_rate as usize * 10) / 1000; // 10ms window
    if window_samples == 0 {
        return Ok(Vec::new());
    }

    let threshold_linear = 10.0f32.powf(threshold_db / 20.0);
    let threshold_sq = threshold_linear * threshold_linear;

    let mut silent_windows: Vec<bool> = Vec::new();

    for chunk in all_samples.chunks(window_samples) {
        let rms_sq = chunk.iter().map(|s| s * s).sum::<f32>() / chunk.len() as f32;
        silent_windows.push(rms_sq < threshold_sq);
    }

    // Find contiguous silent regions
    let mut ranges: Vec<TimeRange> = Vec::new();
    let mut start: Option<usize> = None;

    for (i, &is_silent) in silent_windows.iter().enumerate() {
        if is_silent {
            if start.is_none() {
                start = Some(i);
            }
        } else if let Some(s) = start {
            let start_ms = (s as u64) * 10;
            let end_ms = (i as u64) * 10;
            if end_ms - start_ms >= min_duration_ms {
                ranges.push(TimeRange {
                    start_ms: start_ms as i64,
                    end_ms: end_ms as i64,
                });
            }
            start = None;
        }
    }

    // Handle trailing silence
    if let Some(s) = start {
        let end_ms = (silent_windows.len() as u64) * 10;
        let start_ms = (s as u64) * 10;
        if end_ms - start_ms >= min_duration_ms {
            ranges.push(TimeRange {
                start_ms: start_ms as i64,
                end_ms: end_ms as i64,
            });
        }
    }

    Ok(ranges)
}

#[cfg(test)]
#[path = "silence_tests.rs"]
mod tests;
