use crate::CloomError;
use gifski::Settings;
use imgref::ImgVec;
use rgb::RGBA8;
use std::fs;
use std::io::BufWriter;
use std::thread;

/// Configuration for GIF export.
#[derive(Debug, uniffi::Record)]
pub struct GifConfig {
    pub width: u32,
    pub height: u32,
    pub fps: u8,
    pub quality: u8,
    pub repeat_count: i16,
}

/// Callback interface for reporting GIF export progress.
#[uniffi::export(callback_interface)]
pub trait GifProgressCallback: Send + Sync {
    fn on_progress(&self, fraction: f32);
}

/// Export frames listed in a manifest file to an animated GIF.
///
/// The manifest is a text file where each line is:
///   `<timestamp_ms>\t<path_to_png>`
///
/// Returns the output path on success.
#[uniffi::export]
pub fn export_gif(
    manifest_path: String,
    output_path: String,
    config: GifConfig,
    progress: Box<dyn GifProgressCallback>,
) -> Result<String, CloomError> {
    // Parse manifest
    let manifest = fs::read_to_string(&manifest_path).map_err(|e| CloomError::IoError {
        msg: format!("Failed to read manifest: {e}"),
    })?;

    let lines: Vec<&str> = manifest.lines().filter(|l| !l.is_empty()).collect();
    if lines.is_empty() {
        return Err(CloomError::InvalidInput {
            msg: "Manifest is empty".into(),
        });
    }

    let frame_count = lines.len();

    // Set up gifski
    let settings = Settings {
        width: if config.width > 0 {
            Some(config.width)
        } else {
            None
        },
        height: if config.height > 0 {
            Some(config.height)
        } else {
            None
        },
        quality: config.quality,
        fast: false,
        repeat: match config.repeat_count {
            0 => gifski::Repeat::Infinite,
            n if n > 0 => gifski::Repeat::Finite(n as u16),
            _ => gifski::Repeat::Infinite,
        },
    };

    let (collector, writer) = gifski::new(settings).map_err(|e| CloomError::ExportError {
        msg: format!("Failed to create gifski: {e}"),
    })?;

    let frame_delay = 1.0 / config.fps as f64;

    // Writer thread
    let out_path = output_path.clone();
    let writer_handle = thread::spawn(move || -> Result<(), CloomError> {
        let file = fs::File::create(&out_path).map_err(|e| CloomError::IoError {
            msg: format!("Failed to create output file: {e}"),
        })?;
        let buf_writer = BufWriter::new(file);
        writer.write(buf_writer, &mut gifski::progress::NoProgress {}).map_err(|e| {
            CloomError::ExportError {
                msg: format!("gifski writer error: {e}"),
            }
        })?;
        Ok(())
    });

    // Feed frames to collector
    for (i, line) in lines.iter().enumerate() {
        let parts: Vec<&str> = line.splitn(2, '\t').collect();
        if parts.len() < 2 {
            continue;
        }
        let png_path = parts[1];

        match load_png_as_rgba(png_path) {
            Ok(img) => {
                let presentation_timestamp = i as f64 * frame_delay;
                collector
                    .add_frame_rgba(i, img, presentation_timestamp)
                    .map_err(|e| CloomError::ExportError {
                        msg: format!("Failed to add frame {i}: {e}"),
                    })?;
            }
            Err(e) => {
                eprintln!("Warning: skipping frame {i}: {e}");
            }
        }

        progress.on_progress((i + 1) as f32 / frame_count as f32);
    }

    // Drop collector to signal end of frames
    drop(collector);

    // Wait for writer
    writer_handle
        .join()
        .map_err(|_| CloomError::ExportError {
            msg: "Writer thread panicked".into(),
        })?
        .map_err(|e| CloomError::ExportError {
            msg: format!("Writer error: {e}"),
        })?;

    Ok(output_path)
}

/// Load a PNG file and return an ImgVec<RGBA8> for gifski.
fn load_png_as_rgba(path: &str) -> Result<ImgVec<RGBA8>, CloomError> {
    let png_data = fs::read(path).map_err(|e| CloomError::IoError {
        msg: format!("Failed to read PNG {path}: {e}"),
    })?;

    let decoder = png::Decoder::new(std::io::Cursor::new(&png_data));
    let mut reader = decoder.read_info().map_err(|e| CloomError::ExportError {
        msg: format!("PNG decode error: {e}"),
    })?;

    let mut buf = vec![0u8; reader.output_buffer_size()];
    let info = reader.next_frame(&mut buf).map_err(|e| CloomError::ExportError {
        msg: format!("PNG frame read error: {e}"),
    })?;

    let width = info.width as usize;
    let height = info.height as usize;

    let pixels: Vec<RGBA8> = match info.color_type {
        png::ColorType::Rgba => buf[..width * height * 4]
            .chunks_exact(4)
            .map(|c| RGBA8::new(c[0], c[1], c[2], c[3]))
            .collect(),
        png::ColorType::Rgb => buf[..width * height * 3]
            .chunks_exact(3)
            .map(|c| RGBA8::new(c[0], c[1], c[2], 255))
            .collect(),
        other => {
            return Err(CloomError::ExportError {
                msg: format!("Unsupported PNG color type: {other:?}"),
            });
        }
    };

    Ok(ImgVec::new(pixels, width, height))
}

#[cfg(test)]
#[path = "gif_export_tests.rs"]
mod tests;
