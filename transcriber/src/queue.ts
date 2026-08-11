import PQueue from 'p-queue';
import { QueueItem, TranscriberConfig } from './types.js';
import { Worker } from './worker.js';
import { ApiClient } from './api-client.js';
import { FileManager } from './file-manager.js';
import { logger } from './logger.js';

export class TranscriptionQueue {
  private queue: PQueue;
  private workers: Worker[] = [];
  private queuedItems: QueueItem[] = [];

  constructor(
    private config: TranscriberConfig,
    private apiClient: ApiClient,
    private fileManager: FileManager
  ) {
    this.queue = new PQueue({ concurrency: config.numWorkers });

    // Initialize workers
    for (let i = 0; i < config.numWorkers; i++) {
      this.workers.push(new Worker(i + 1, apiClient, fileManager, config));
    }

    logger.info(`Queue initialized with ${config.numWorkers} workers`);
  }

  async enqueue(filePath: string): Promise<void> {
    const item: QueueItem = {
      filePath,
      retries: 0,
      addedAt: new Date(),
    };

    this.queuedItems.push(item);
    logger.info(
      `Enqueued: ${filePath} (queue size: ${this.queuedItems.length})`
    );

    // Add to p-queue with worker assignment
    const workerIndex = this.queuedItems.length % this.config.numWorkers;
    const worker = this.workers[workerIndex];

    this.queue.add(async () => {
      // Remove from queued items when processing starts
      this.queuedItems = this.queuedItems.filter(
        (i) => i.filePath !== item.filePath
      );
      await worker.process(item);
    });
  }

  getStatus(): { queueSize: number; workers: any[] } {
    return {
      queueSize: this.queuedItems.length,
      workers: this.workers.map((w, i) => ({
        id: i + 1,
        ...w.getStats(),
      })),
    };
  }

  async waitForCompletion(): Promise<void> {
    await this.queue.onIdle();
    logger.info('All queued items processed');
  }
}
