use crate::errors::{AppError, Result};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use tokio::time::Duration;

pub struct AudioRecorder {
    process: Option<Child>,
    chunk_duration: u32,
    output_dir: PathBuf,
}

impl AudioRecorder {
    pub fn new(output_dir: PathBuf, chunk_duration: u32) -> Self {
        Self {
            process: None,
            chunk_duration,
            output_dir,
        }
    }

    pub async fn start(&mut self) -> Result<()> {
        if self.process.is_some() {
            return Err(AppError::Recording(
                "Recording already in progress".to_string(),
            ));
        }

        // Create output directory if it doesn't exist
        tokio::fs::create_dir_all(&self.output_dir)
            .await
            .map_err(|e| AppError::File(format!("Failed to create output directory: {}", e)))?;

        let output_path = format!(
            "{}/chunk_%Y%m%d_%H%M%S.mp3",
            self.output_dir.display()
        );

        let mut cmd = Command::new("ffmpeg");
        // Use only built-in microphone for now (BlackHole not required for testing)
        // Once BlackHole is installed, this can be changed back to use both inputs:
        // "-i", ":BlackHole 2ch", "-i", ":Built-in Microphone",
        // "-filter_complex", "[0:a][1:a]amix=inputs=2:duration=first",
        cmd.args(&[
            "-f", "avfoundation",
            "-audio_device_index", "0",  // MacBook Pro Microphone
            "-i", "none",  // No video input, audio only
            "-af", "anlmdn,volume=3.0,highpass=f=100,lowpass=f=12000,loudnorm=I=-15:TP=-0.3:LRA=11",  // Noise reduction + high volume boost + filters + aggressive loudness normalization
            "-codec:a", "libmp3lame",
            "-b:a", "320k",  // Maximum bitrate for MP3 (was 256k)
            "-q:a", "0",  // Highest MP3 quality (0 is best)
            "-f", "segment",
            "-segment_time", &self.chunk_duration.to_string(),
            "-segment_format", "mp3",
            "-strftime", "1",  // Enable strftime time format codes in filename
            "-reset_timestamps", "1",
        ])
        .arg(&output_path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());

        let child = cmd
            .spawn()
            .map_err(|e| AppError::Recording(format!("Failed to start FFmpeg: {}", e)))?;

        self.process = Some(child);

        log::info!(
            "Started recording with {} second chunks to {}",
            self.chunk_duration,
            self.output_dir.display()
        );

        Ok(())
    }

    pub async fn stop(&mut self) -> Result<()> {
        if let Some(mut child) = self.process.take() {
            // Attempt to kill the FFmpeg process
            let _ = child.kill();

            // Wait for process to finish (with timeout)
            let wait_result = tokio::spawn(async move {
                let _ = child.wait();
            });

            match tokio::time::timeout(Duration::from_secs(5), wait_result).await {
                Ok(_) => {
                    log::info!("Recording stopped");
                    Ok(())
                }
                Err(_) => {
                    log::warn!("FFmpeg did not stop within timeout");
                    Ok(())
                }
            }
        } else {
            Err(AppError::Recording(
                "No recording in progress".to_string(),
            ))
        }
    }

    #[allow(dead_code)]
    pub fn is_recording(&self) -> bool {
        self.process.is_some()
    }

    #[allow(dead_code)]
    pub fn set_chunk_duration(&mut self, duration: u32) {
        self.chunk_duration = duration;
    }
}
