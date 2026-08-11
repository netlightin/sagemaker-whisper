import { Command } from 'commander';
import { config } from './config.js';
import { logger } from './logger.js';
import { ApiClient } from './api-client.js';
import { FileManager } from './file-manager.js';
import { TranscriptionQueue } from './queue.js';
import { FileWatcher } from './watcher.js';

const program = new Command();
let watcher: FileWatcher | null = null;

program
  .name('audio-transcriber')
  .description('Transcribes audio files using API')
  .version('1.0.0');

program
  .command('start')
  .description('Start watching and transcribing')
  .action(async () => {
    try {
      // Initialize components
      const fileManager = new FileManager(config);
      await fileManager.initialize();

      const apiClient = new ApiClient(config);
      const queue = new TranscriptionQueue(config, apiClient, fileManager);
      watcher = new FileWatcher(config, queue, fileManager);

      // Start watcher
      await watcher.start();

      logger.info('Transcriber started. Press Ctrl+C to stop.');

      // Status reporting interval
      setInterval(() => {
        const status = queue.getStatus();
        logger.info(
          `Status - Queue: ${status.queueSize}, Workers: ${JSON.stringify(status.workers)}`
        );
      }, 30000); // Every 30 seconds

      // Keep process alive
      await new Promise(() => {});
    } catch (error) {
      logger.error('Failed to start transcriber:', error);
      process.exit(1);
    }
  });

// Handle graceful shutdown
process.on('SIGINT', async () => {
  logger.info('Received SIGINT, shutting down...');
  if (watcher?.isActive()) {
    watcher.stop();
  }
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logger.info('Received SIGTERM, shutting down...');
  if (watcher?.isActive()) {
    watcher.stop();
  }
  process.exit(0);
});

program.parse();
