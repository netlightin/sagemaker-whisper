import { Command } from 'commander';
import { AudioRecorder } from './recorder.js';
import { config } from './config.js';
import { logger } from './logger.js';

const program = new Command();
let recorder: AudioRecorder | null = null;

program
  .name('audio-recorder')
  .description('Records audio in chunks using FFmpeg')
  .version('1.0.0');

program
  .command('start')
  .description('Start recording')
  .option('-d, --duration <seconds>', 'Chunk duration in seconds', '60')
  .action(async (options) => {
    try {
      recorder = new AudioRecorder({
        ...config,
        chunkDuration: parseInt(options.duration),
      });
      await recorder.start();
      console.log('Recording started. Press Ctrl+C to stop.');
    } catch (error) {
      logger.error('Failed to start recording:', error);
      process.exit(1);
    }
  });

program
  .command('stop')
  .description('Stop recording')
  .action(async () => {
    if (!recorder) {
      console.error('No recorder instance');
      process.exit(1);
    }
    try {
      await recorder.stop();
      process.exit(0);
    } catch (error) {
      logger.error('Failed to stop recording:', error);
      process.exit(1);
    }
  });

// Handle graceful shutdown
process.on('SIGINT', async () => {
  logger.info('Received SIGINT, stopping recorder...');
  if (recorder?.isRecording()) {
    await recorder.stop();
  }
  process.exit(0);
});

process.on('SIGTERM', async () => {
  logger.info('Received SIGTERM, stopping recorder...');
  if (recorder?.isRecording()) {
    await recorder.stop();
  }
  process.exit(0);
});

program.parse();
