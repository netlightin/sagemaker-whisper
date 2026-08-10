use std::sync::Arc;
use tokio::sync::Mutex;

pub mod recording;
pub mod transcription;

pub use recording::{start_recording, stop_recording};
pub use transcription::get_queue_status;

#[derive(Clone)]
pub struct AppState {
    pub recorder_state: Arc<Mutex<Option<crate::services::audio_recorder::AudioRecorder>>>,
    pub queue_state: Arc<Mutex<Option<crate::services::transcription_queue::TranscriptionQueue>>>,
    pub is_recording: Arc<Mutex<bool>>,
}

impl AppState {
    pub fn new() -> Self {
        Self {
            recorder_state: Arc::new(Mutex::new(None)),
            queue_state: Arc::new(Mutex::new(None)),
            is_recording: Arc::new(Mutex::new(false)),
        }
    }
}
