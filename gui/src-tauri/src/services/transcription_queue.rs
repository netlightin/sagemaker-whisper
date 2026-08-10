use crate::errors::{AppError, Result};
use crate::services::api_client::ApiClient;
use std::collections::VecDeque;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use tauri::{AppHandle, Emitter};
use tokio::sync::Mutex;
use tokio::time::{sleep, Duration};

#[allow(dead_code)]
pub struct TranscriptionQueue {
    queue: Arc<Mutex<VecDeque<PathBuf>>>,
    is_processing: Arc<AtomicBool>,
    current_files: Arc<Mutex<Vec<String>>>,
    app_handle: AppHandle,
    api_client: ApiClient,
    processed_dir: PathBuf,
    max_retries: u32,
    num_workers: usize,
}

impl TranscriptionQueue {
    #[allow(dead_code)]
    pub fn new(app_handle: AppHandle, processed_dir: PathBuf, max_retries: u32) -> Self {
        Self {
            queue: Arc::new(Mutex::new(VecDeque::new())),
            is_processing: Arc::new(AtomicBool::new(false)),
            current_files: Arc::new(Mutex::new(Vec::new())),
            app_handle,
            api_client: ApiClient::new(),
            processed_dir,
            max_retries,
            num_workers: 2,
        }
    }

    #[allow(dead_code)]
    pub async fn enqueue(&self, file: PathBuf) {
        {
            let mut queue = self.queue.lock().await;
            queue.push_back(file);
        } // Release queue lock before emitting status

        self.emit_status_update().await;

        // Start workers if not already running
        if !self.is_processing.load(Ordering::SeqCst) {
            for _ in 0..self.num_workers {
                self.spawn_worker();
            }
        }
    }

    pub async fn get_status(&self) -> (usize, Vec<String>) {
        let queue_len = self.queue.lock().await.len();
        let current = self.current_files.lock().await.clone();
        (queue_len, current)
    }

    #[allow(dead_code)]
    fn spawn_worker(&self) {
        let queue = self.queue.clone();
        let is_processing = self.is_processing.clone();
        let current_files = self.current_files.clone();
        let app_handle = self.app_handle.clone();
        let api_client = ApiClient::new();
        let processed_dir = self.processed_dir.clone();
        let max_retries = self.max_retries;

        tokio::spawn(async move {
            is_processing.store(true, Ordering::SeqCst);

            loop {
                let file = {
                    let mut q = queue.lock().await;
                    q.pop_front()
                };

                match file {
                    Some(file_path) => {
                        // Get file name
                        let file_name = file_path
                            .file_name()
                            .map(|n| n.to_string_lossy().to_string())
                            .unwrap_or_else(|| "unknown".to_string());

                        // Add to current files being processed
                        {
                            let mut current = current_files.lock().await;
                            current.push(file_name.clone());
                        }

                        let _ = app_handle.emit(
                            "transcription:processing",
                            serde_json::json!({ "file": file_name }),
                        );

                        log::info!("Worker started transcribing: {}", file_name);

                        // Process file with retries
                        let mut retry_count = 0;
                        let mut success = false;

                        while retry_count < max_retries && !success {
                            match api_client.transcribe_audio(&file_path).await {
                                Ok(transcript) => {
                                    // Save transcript
                                    if let Err(e) = save_transcript(&file_path, &transcript, &processed_dir).await {
                                        log::error!("Failed to save transcript: {}", e);
                                        let _ = app_handle.emit(
                                            "transcription:error",
                                            serde_json::json!({ "file": file_name, "error": e.to_string() }),
                                        );
                                    } else {
                                        // Move audio file
                                        if let Err(e) = move_to_processed(&file_path, &processed_dir).await {
                                            log::error!("Failed to move file: {}", e);
                                        }

                                        success = true;
                                        let _ = app_handle.emit(
                                            "transcription:completed",
                                            serde_json::json!({ "file": file_name }),
                                        );
                                    }
                                }
                                Err(e) => {
                                    retry_count += 1;
                                    log::warn!(
                                        "Transcription failed (attempt {}/{}): {}",
                                        retry_count,
                                        max_retries,
                                        e
                                    );

                                    if retry_count >= max_retries {
                                        let _ = app_handle.emit(
                                            "transcription:error",
                                            serde_json::json!({
                                                "file": file_name,
                                                "error": format!("Failed after {} retries: {}", max_retries, e)
                                            }),
                                        );
                                    } else {
                                        // Exponential backoff
                                        let wait_time = 2u64.pow(retry_count) * 1000; // milliseconds
                                        sleep(Duration::from_millis(wait_time)).await;
                                    }
                                }
                            }
                        }

                        // Remove from current files
                        {
                            let mut current = current_files.lock().await;
                            current.retain(|f| f != &file_name);
                        }

                        log::info!("Worker finished transcribing: {}", file_name);
                    }
                    None => break,
                }
            }

            is_processing.store(false, Ordering::SeqCst);
        });
    }

    #[allow(dead_code)]
    async fn emit_status_update(&self) {
        let (queue_len, current_files) = self.get_status().await;
        let _ = self.app_handle.emit(
            "queue:status",
            serde_json::json!({
                "queue_length": queue_len,
                "current_files": current_files
            }),
        );
    }
}

#[allow(dead_code)]
async fn save_transcript(
    audio_file: &PathBuf,
    transcript: &str,
    processed_dir: &PathBuf,
) -> Result<()> {
    let transcript_dir = processed_dir.join("transcripts");
    tokio::fs::create_dir_all(&transcript_dir)
        .await
        .map_err(|e| AppError::File(format!("Failed to create transcripts dir: {}", e)))?;

    let file_stem = audio_file
        .file_stem()
        .ok_or_else(|| AppError::File("Invalid file name".to_string()))?
        .to_string_lossy();

    let transcript_path = transcript_dir.join(format!("{}.txt", file_stem));

    tokio::fs::write(&transcript_path, transcript)
        .await
        .map_err(|e| AppError::File(format!("Failed to write transcript: {}", e)))?;

    log::info!("Transcript saved: {}", transcript_path.display());
    Ok(())
}

#[allow(dead_code)]
async fn move_to_processed(audio_file: &PathBuf, processed_dir: &PathBuf) -> Result<()> {
    let audio_dir = processed_dir.join("audio");
    tokio::fs::create_dir_all(&audio_dir)
        .await
        .map_err(|e| AppError::File(format!("Failed to create audio dir: {}", e)))?;

    let file_name = audio_file
        .file_name()
        .ok_or_else(|| AppError::File("Invalid file name".to_string()))?;

    let destination = audio_dir.join(file_name);

    tokio::fs::rename(audio_file, &destination)
        .await
        .map_err(|e| AppError::File(format!("Failed to move file: {}", e)))?;

    log::info!("Audio file moved: {}", destination.display());
    Ok(())
}
