use crate::commands::AppState;
use crate::models::QueueStatus;
use tauri::State;

#[tauri::command]
pub async fn get_queue_status(
    state: State<'_, AppState>,
) -> std::result::Result<QueueStatus, String> {
    let is_recording = *state.is_recording.lock().await;

    let (queue_length, current_files) = if let Some(ref queue) = *state.queue_state.lock().await {
        queue.get_status().await
    } else {
        (0, Vec::new())
    };

    Ok(QueueStatus {
        is_recording,
        queue_length,
        current_files,
        last_error: None,
    })
}
