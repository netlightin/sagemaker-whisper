use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueueStatus {
    pub is_recording: bool,
    pub queue_length: usize,
    pub current_files: Vec<String>,
    pub last_error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[allow(dead_code)]
pub struct TranscriptionResponse {
    pub text: String,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct AudioFile {
    pub path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[allow(dead_code)]
pub struct AppConfig {
    pub chunk_duration: u32,
    pub audio_bitrate: u32,
    pub max_retries: u32,
    pub aggregate_device_name: String,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            chunk_duration: 60,
            audio_bitrate: 128,
            max_retries: 3,
            aggregate_device_name: "Transcription Aggregate".to_string(),
        }
    }
}
