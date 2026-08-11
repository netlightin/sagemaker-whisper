import { readdir, stat } from 'fs/promises';
import path from 'path';
import { TranscriberConfig } from './types.js';
import { TranscriptionQueue } from './queue.js';
import { FileManager } from './file-manager.js';
import { logger } from './logger.js';

export class FileWatcher {
  private seenFiles = new Set<string>();
  private isRunning = false;
  private intervalId: NodeJS.Timeout | null = null;

  constructor(
    private config: TranscriberConfig,
    private queue: TranscriptionQueue,
    private fileManager: FileManager
  ) {}

  async start(): Promise<void> {
    if (this.isRunning) {
      throw new Error('Watcher already running');
    }

    this.isRunning = true;
    logger.info(
      `File watcher started (polling every ${this.config.pollInterval}ms): ${this.config.pendingDir}`
    );

    this.intervalId = setInterval(async () => {
      await this.poll();
    }, this.config.pollInterval);
  }

  private async poll(): Promise<void> {
    try {
      const files = await readdir(this.config.pendingDir);

      for (const file of files) {
        const filePath = path.join(this.config.pendingDir, file);

        // Skip if already seen
        if (this.seenFiles.has(filePath)) {
          continue;
        }

        // Check if it's an mp3 file
        if (!file.endsWith('.mp3')) {
          continue;
        }

        try {
          const stats = await stat(filePath);

          // Check if file is large enough
          if (!stats.isFile() || stats.size < this.config.minFileSize) {
            continue;
          }

          // Mark as seen
          this.seenFiles.add(filePath);
          logger.info(`New file detected: ${filePath}`);

          // Wait for stabilization
          await new Promise((resolve) =>
            setTimeout(resolve, this.config.stabilizationDelay)
          );

          // Double-check file still exists and meets size requirement
          if (await this.fileManager.isFileReady(filePath)) {
            logger.info(`File ready for transcription: ${filePath}`);
            await this.queue.enqueue(filePath);
          }
        } catch (error) {
          logger.error(`Error checking file ${filePath}:`, error);
        }
      }
    } catch (error) {
      logger.error('Error polling directory:', error);
    }
  }

  stop(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    this.isRunning = false;
    logger.info('File watcher stopped');
  }

  isActive(): boolean {
    return this.isRunning;
  }
}
