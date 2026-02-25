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
