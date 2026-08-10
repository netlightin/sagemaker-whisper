// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod errors;
mod models;
mod services;

use commands::{start_recording, stop_recording, get_queue_status, AppState};
use std::path::PathBuf;

fn main() {
    env_logger::init();

    let app_state = AppState::new();

    tauri::Builder::default()
        .manage(app_state.clone())
        .invoke_handler(tauri::generate_handler![
            start_recording,
            stop_recording,
            get_queue_status,
        ])
        .setup(move |app| {
            // Initialize directories - use current exe to find the gui directory
            let exe_path = std::env::current_exe().expect("Failed to get executable path");
            let gui_dir = exe_path
                .parent()
                .and_then(|p| p.parent())
                .and_then(|p| p.parent())
                .and_then(|p| p.parent())
                .expect("Could not determine gui directory");
            let app_dir = gui_dir.join("data");
            let pending_dir = app_dir.join("pending");
            let processed_dir = app_dir.join("processed");

            let state_clone = app_state.clone();
            let app_handle = app.handle().clone();
            let pending_for_watcher = pending_dir.clone();

            // Create directories synchronously
            std::fs::create_dir_all(&pending_dir).ok();
            std::fs::create_dir_all(&processed_dir).ok();
            log::info!("Directories initialized at {}", app_dir.display());

            // Initialize transcription queue
            let queue = crate::services::transcription_queue::TranscriptionQueue::new(
                app_handle.clone(),
                processed_dir.clone(),
                3, // max_retries
            );

            {
                if let Ok(mut queue_state) = state_clone.queue_state.try_lock() {
                    *queue_state = Some(queue);
                }
            }

            // Start file watcher in separate async task
            let state_for_watcher = state_clone.clone();
            std::thread::spawn(move || {
                tauri::async_runtime::block_on(async {
                    if let Ok(mut watcher) = crate::services::file_watcher::FileWatcher::new(pending_for_watcher.clone()) {
                        let state = state_for_watcher.clone();

                        if let Err(e) = watcher.start(move |file_path| {
                            log::info!("File detected by watcher: {}", file_path.display());
                            let state = state.clone();
                            tokio::spawn(async move {
                                log::info!("Attempting to access queue for: {}", file_path.display());
                                match state.queue_state.lock().await {
                                    guard => {
                                        if let Some(ref queue) = *guard {
                                            log::info!("Queue found, enqueueing: {}", file_path.display());
                                            queue.enqueue(file_path.clone()).await;
                                            log::info!("File added to transcription queue");
                                        } else {
                                            log::warn!("Queue is None!");
                                        }
                                    }
                                }
                            });
                        }).await {
                            log::error!("Failed to start file watcher: {}", e);
                        }
                    } else {
                        log::error!("Failed to initialize file watcher");
                    }
                });
            });

            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
