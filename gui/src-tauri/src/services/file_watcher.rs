use crate::errors::{AppError, Result};
use std::collections::{VecDeque, HashSet};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio::time::{sleep, Duration};

#[allow(dead_code)]
pub type FileCallback = Arc<dyn Fn(PathBuf) + Send + Sync>;

#[allow(dead_code)]
pub struct FileWatcher {
    pending_dir: PathBuf,
    watched_files: Arc<Mutex<VecDeque<PathBuf>>>,
}

impl FileWatcher {
    #[allow(dead_code)]
    pub fn new(pending_dir: PathBuf) -> Result<Self> {
        Ok(Self {
            pending_dir,
            watched_files: Arc::new(Mutex::new(VecDeque::new())),
        })
    }

    #[allow(dead_code)]
    pub async fn start<F: Fn(PathBuf) + Send + Sync + 'static>(
        &mut self,
        on_file_ready: F,
    ) -> Result<()> {
        let pending_dir = self.pending_dir.clone();
        let watched_files = self.watched_files.clone();
        let callback = Arc::new(on_file_ready);

        log::info!("File watcher started (polling-based) for: {}", pending_dir.display());

        // Spawn a polling task to check for new files every 500ms
        tokio::spawn(async move {
            let mut seen_files = HashSet::new();

            loop {
                sleep(Duration::from_millis(500)).await;

                if let Ok(entries) = std::fs::read_dir(&pending_dir) {
                    for entry in entries.flatten() {
                        if let Ok(metadata) = entry.metadata() {
                            if metadata.is_file() {
                                let path = entry.path();
                                if path.extension().map_or(false, |ext| ext == "mp3") {
                                    let path_str = path.to_string_lossy().to_string();
                                    if !seen_files.contains(&path_str) && metadata.len() > 100000 {
                                        seen_files.insert(path_str.clone());
                                        log::info!("New file detected: {}", path.display());

                                        // Wait a bit to ensure file is fully written
                                        sleep(Duration::from_millis(100)).await;

                                        if path.exists() && metadata.len() > 100000 {
                                            watched_files.lock().await.push_back(path.clone());
                                            log::info!("File ready for transcription: {}", path.display());
                                            callback(path);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        });

        Ok(())
    }

    #[allow(dead_code)]
    pub async fn get_pending_files(&self) -> Vec<PathBuf> {
        self.watched_files.lock().await.iter().cloned().collect()
    }

    #[allow(dead_code)]
    pub async fn remove_file(&self, file: &PathBuf) {
        let mut files = self.watched_files.lock().await;
        files.retain(|f| f != file);
    }
}
