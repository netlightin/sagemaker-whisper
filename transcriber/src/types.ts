export interface TranscriberConfig {
  pendingDir: string;
  processedAudioDir: string;
  processedTranscriptDir: string;
  apiEndpoint: string;
  apiKey: string;
  maxRetries: number;
  numWorkers: number;
  pollInterval: number;
  minFileSize: number;
  stabilizationDelay: number;
  apiTimeout: number;
}

export interface QueueItem {
  filePath: string;
  retries: number;
  addedAt: Date;
}

export interface TranscriptionResult {
  text: string;
}

export interface WorkerStats {
  processed: number;
  failed: number;
  currentFile: string | null;
}
