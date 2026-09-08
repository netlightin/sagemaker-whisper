export interface RecorderConfig {
  chunkDuration: number;           // Seconds between file splits
  outputDir: string;               // Output directory path
  obsWebSocketUrl: string;         // e.g., 'ws://127.0.0.1:4455'
  obsWebSocketPassword: string;    // OBS WebSocket password
  logLevel: string;                // Winston log level
}

export interface RecorderState {
  isRecording: boolean;
  recordingStartTime: Date | null;
  splitCount: number;
}

export interface OBSConnectionState {
  isConnected: boolean;
  obsVersion: string | null;
  lastConnectionTime: Date | null;
}
