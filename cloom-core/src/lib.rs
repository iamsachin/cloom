uniffi::setup_scaffolding!();

mod runtime;

mod ai;
pub use ai::transcribe::*;
pub use ai::llm::*;

mod audio;
pub use audio::filler::*;
pub use audio::silence::*;

use thiserror::Error;

/// Error type exposed across the FFI boundary.
#[derive(Debug, Error, uniffi::Error)]
pub enum CloomError {
    #[error("IO error: {msg}")]
    IoError { msg: String },
    #[error("API error: {msg}")]
    ApiError { msg: String },
    #[error("Audio error: {msg}")]
    AudioError { msg: String },
    #[error("Invalid input: {msg}")]
    InvalidInput { msg: String },
    #[error("Export error: {msg}")]
    ExportError { msg: String },
}

/// Initialize Rust logging, routing log macros to macOS Console.app via os_log.
/// Safe to call multiple times — only the first call takes effect.
#[uniffi::export]
pub fn cloom_setup_logging() {
    use std::sync::Once;
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        oslog::OsLogger::new("com.cloom.app")
            .level_filter(log::LevelFilter::Debug)
            .init()
            .ok();
    });
}

/// Simple hello-world function to verify FFI round-trip.
#[uniffi::export]
pub fn hello_from_rust(name: String) -> String {
    format!("Hello from Rust, {}! cloom-core is alive.", name)
}

/// Returns the cloom-core library version.
#[uniffi::export]
pub fn cloom_core_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_hello() {
        let result = hello_from_rust("Cloom".to_string());
        assert!(result.contains("Cloom"));
        assert!(result.contains("cloom-core is alive"));
    }

    #[test]
    fn test_version() {
        let version = cloom_core_version();
        assert_eq!(version, env!("CARGO_PKG_VERSION"));
    }
}
