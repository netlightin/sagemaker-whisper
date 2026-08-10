use crate::commands::AppState;
use crate::services::audio_recorder::AudioRecorder;
use tauri::State;
use std::path::PathBuf;

#[tauri::command]
pub async fn start_recording(
    chunk_duration: Option<u32>,
    state: State<'_, AppState>,
    _app_handle: tauri::AppHandle,
) -> std::result::Result<String, String> {
    let chunk_duration = chunk_duration.unwrap_or(60);

    // Get app data directory - use current exe to find the gui directory
    let exe_path = std::env::current_exe()
        .map_err(|e| format!("Failed to get executable path: {}", e))?;
    let gui_dir = exe_path
        .parent()
        .and_then(|p| p.parent())
        .and_then(|p| p.parent())
        .and_then(|p| p.parent())
        .ok_or_else(|| "Could not determine gui directory".to_string())?;
    let app_dir = gui_dir.join("data");
    let pending_dir = app_dir.join("pending");

    log::info!("Using data directory: {}", app_dir.display());

    // Create directories
    tokio::fs::create_dir_all(&pending_dir)
        .await
        .map_err(|e| format!("Failed to create directories: {}", e))?;

    // Create and start recorder
    let mut recorder = AudioRecorder::new(pending_dir, chunk_duration);
    recorder.start().await.map_err(|e| e.to_string())?;

    *state.is_recording.lock().await = true;
    *state.recorder_state.lock().await = Some(recorder);

    log::info!("Recording started with {} second chunks", chunk_duration);

    Ok("Recording started".to_string())
}

#[tauri::command]
pub async fn stop_recording(
    state: State<'_, AppState>,
) -> std::result::Result<String, String> {
    let mut is_recording = state.is_recording.lock().await;

    if !*is_recording {
        return Err("Recording not in progress".to_string());
    }

    let mut recorder_lock = state.recorder_state.lock().await;

    if let Some(ref mut recorder) = *recorder_lock {
        recorder.stop().await.map_err(|e| e.to_string())?;
    }

    *is_recording = false;

    log::info!("Recording stopped");

    Ok("Recording stopped".to_string())
}
