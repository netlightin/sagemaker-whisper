import { Command } from 'commander';
import { OBSRecorder } from './recorder.js';
import { config } from './config.js';
import { logger } from './logger.js';

const program = new Command();
let recorder: OBSRecorder | null = null;

program
  .name('obs-audio-recorder')
  .description('Records audio via OBS WebSocket in chunks')
  .version('1.0.0');

program
  .command('start')
  .description('Start recording')
  .option('-d, --duration <seconds>', 'Chunk duration in seconds', '60')
  .action(async (options) => {
    try {
      recorder = new OBSRecorder({
        ...config,
        chunkDuration: parseInt(options.duration),
      });
      await recorder.start();
      console.log('Recording started via OBS. Press Ctrl+C to stop.');
    } catch (error: any) {
      logger.error('Failed to start recording:', error);
      if (error.message?.includes('OBS')) {
        console.error(
          '\nError: OBS is not running or WebSocket is not enabled.'
        );
        console.error(
          'Please start OBS and enable WebSocket in Tools > obs-websocket Settings'
        );
      }
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
