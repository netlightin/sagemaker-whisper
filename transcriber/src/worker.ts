import { ApiClient } from './api-client.js';
import { FileManager } from './file-manager.js';
import { QueueItem, TranscriberConfig, WorkerStats } from './types.js';
import { logger } from './logger.js';

export class Worker {
  private stats: WorkerStats = {
    processed: 0,
    failed: 0,
    currentFile: null,
  };

  constructor(
    private id: number,
    private apiClient: ApiClient,
    private fileManager: FileManager,
    private config: TranscriberConfig
  ) {}

  async process(item: QueueItem): Promise<void> {
    this.stats.currentFile = item.filePath;
    logger.info(`Worker ${this.id} processing: ${item.filePath}`);

    let lastError: Error | null = null;

    for (let attempt = 0; attempt < this.config.maxRetries; attempt++) {
      try {
        // Transcribe audio
        const transcript = await this.apiClient.transcribeAudio(item.filePath);

        // Save transcript
        await this.fileManager.saveTranscript(item.filePath, transcript);

        // Move audio file
        await this.fileManager.moveToProcessed(item.filePath);

        this.stats.processed++;
        this.stats.currentFile = null;
        logger.info(`Worker ${this.id} completed: ${item.filePath}`);
        return;
      } catch (error) {
        lastError = error as Error;
        logger.warn(
          `Worker ${this.id} transcription failed (attempt ${attempt + 1}/${this.config.maxRetries}): ${lastError.message}`
        );

        if (attempt < this.config.maxRetries - 1) {
          // Exponential backoff: 2s, 4s, 8s
          const waitTime = Math.pow(2, attempt + 1) * 1000;
          await new Promise((resolve) => setTimeout(resolve, waitTime));
        }
      }
    }

    this.stats.failed++;
    this.stats.currentFile = null;
    logger.error(
      `Worker ${this.id} failed after ${this.config.maxRetries} retries: ${item.filePath}`,
      {
        error: lastError?.message,
      }
    );
  }

  getStats(): WorkerStats {
    return { ...this.stats };
  }
}
