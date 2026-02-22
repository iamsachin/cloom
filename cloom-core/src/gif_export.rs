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
mod tests {
    use super::*;
    use std::io::Write;
    use std::sync::atomic::{AtomicU32, Ordering};
    use std::sync::Arc;

    struct TestProgress {
        call_count: Arc<AtomicU32>,
    }

    impl GifProgressCallback for TestProgress {
        fn on_progress(&self, _fraction: f32) {
            self.call_count.fetch_add(1, Ordering::SeqCst);
        }
    }

    /// Create a minimal valid PNG file with a solid color.
    fn create_test_png(w: u32, h: u32, r: u8, g: u8, b: u8) -> tempfile::NamedTempFile {
        let mut file = tempfile::NamedTempFile::with_suffix(".png").unwrap();
        let mut encoder = png::Encoder::new(&mut file, w, h);
        encoder.set_color(png::ColorType::Rgba);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header().unwrap();
        let data: Vec<u8> = (0..w * h)
            .flat_map(|_| vec![r, g, b, 255u8])
            .collect();
        writer.write_image_data(&data).unwrap();
        drop(writer);
        file.flush().unwrap();
        file
    }

    #[test]
    fn test_empty_manifest() {
        let manifest = tempfile::NamedTempFile::new().unwrap();
        std::fs::write(manifest.path(), "").unwrap();

        let output = tempfile::NamedTempFile::with_suffix(".gif").unwrap();
        let progress = Box::new(TestProgress {
            call_count: Arc::new(AtomicU32::new(0)),
        });

        let result = export_gif(
            manifest.path().to_str().unwrap().to_string(),
            output.path().to_str().unwrap().to_string(),
            GifConfig {
                width: 100,
                height: 100,
                fps: 10,
                quality: 80,
                repeat_count: 0,
            },
            progress,
        );

        assert!(result.is_err());
        if let Err(CloomError::InvalidInput { msg }) = result {
            assert!(msg.contains("empty"));
        }
    }

    #[test]
    fn test_manifest_not_found() {
        let progress = Box::new(TestProgress {
            call_count: Arc::new(AtomicU32::new(0)),
        });

        let result = export_gif(
            "/nonexistent/manifest.txt".to_string(),
            "/tmp/out.gif".to_string(),
            GifConfig {
                width: 100,
                height: 100,
                fps: 10,
                quality: 80,
                repeat_count: 0,
            },
            progress,
        );

        assert!(result.is_err());
        if let Err(CloomError::IoError { msg }) = result {
            assert!(msg.contains("manifest"));
        }
    }

    #[test]
    fn test_single_frame_export() {
        let png = create_test_png(4, 4, 255, 0, 0); // red 4x4

        let manifest = tempfile::NamedTempFile::new().unwrap();
        let manifest_content = format!("0\t{}", png.path().to_str().unwrap());
        std::fs::write(manifest.path(), manifest_content).unwrap();

        let output = tempfile::NamedTempFile::with_suffix(".gif").unwrap();
        let call_count = Arc::new(AtomicU32::new(0));
        let progress = Box::new(TestProgress {
            call_count: call_count.clone(),
        });

        let result = export_gif(
            manifest.path().to_str().unwrap().to_string(),
            output.path().to_str().unwrap().to_string(),
            GifConfig {
                width: 4,
                height: 4,
                fps: 10,
                quality: 80,
                repeat_count: 0,
            },
            progress,
        );

        assert!(result.is_ok(), "Single frame export failed: {:?}", result.err());
        assert_eq!(call_count.load(Ordering::SeqCst), 1);

        // Verify output file exists and has content
        let output_size = std::fs::metadata(output.path()).unwrap().len();
        assert!(output_size > 0, "GIF output should not be empty");
    }

    #[test]
    fn test_multi_frame_export() {
        let png1 = create_test_png(4, 4, 255, 0, 0);
        let png2 = create_test_png(4, 4, 0, 255, 0);
        let png3 = create_test_png(4, 4, 0, 0, 255);

        let manifest = tempfile::NamedTempFile::new().unwrap();
        let content = format!(
            "0\t{}\n100\t{}\n200\t{}",
            png1.path().to_str().unwrap(),
            png2.path().to_str().unwrap(),
            png3.path().to_str().unwrap(),
        );
        std::fs::write(manifest.path(), content).unwrap();

        let output = tempfile::NamedTempFile::with_suffix(".gif").unwrap();
        let call_count = Arc::new(AtomicU32::new(0));
        let progress = Box::new(TestProgress {
            call_count: call_count.clone(),
        });

        let result = export_gif(
            manifest.path().to_str().unwrap().to_string(),
            output.path().to_str().unwrap().to_string(),
            GifConfig {
                width: 4,
                height: 4,
                fps: 10,
                quality: 80,
                repeat_count: 0,
            },
            progress,
        );

        assert!(result.is_ok(), "Multi frame export failed: {:?}", result.err());
        assert_eq!(call_count.load(Ordering::SeqCst), 3);
    }

    #[test]
    fn test_load_png_rgba() {
        let png = create_test_png(2, 2, 128, 64, 32);
        let img = load_png_as_rgba(png.path().to_str().unwrap()).unwrap();
        assert_eq!(img.width(), 2);
        assert_eq!(img.height(), 2);
        // Check first pixel color
        let pixel = &img.buf()[0];
        assert_eq!(pixel.r, 128);
        assert_eq!(pixel.g, 64);
        assert_eq!(pixel.b, 32);
        assert_eq!(pixel.a, 255);
    }

    #[test]
    fn test_load_png_rgb() {
        // Create an RGB (not RGBA) PNG
        let mut file = tempfile::NamedTempFile::with_suffix(".png").unwrap();
        let w = 2u32;
        let h = 2u32;
        let mut encoder = png::Encoder::new(&mut file, w, h);
        encoder.set_color(png::ColorType::Rgb);
        encoder.set_depth(png::BitDepth::Eight);
        let mut writer = encoder.write_header().unwrap();
        let data: Vec<u8> = (0..w * h).flat_map(|_| vec![100u8, 150, 200]).collect();
        writer.write_image_data(&data).unwrap();
        drop(writer);
        file.flush().unwrap();

        let img = load_png_as_rgba(file.path().to_str().unwrap()).unwrap();
        assert_eq!(img.width(), 2);
        assert_eq!(img.height(), 2);
        let pixel = &img.buf()[0];
        assert_eq!(pixel.r, 100);
        assert_eq!(pixel.g, 150);
        assert_eq!(pixel.b, 200);
        assert_eq!(pixel.a, 255); // RGB → RGBA with alpha=255
    }
}
