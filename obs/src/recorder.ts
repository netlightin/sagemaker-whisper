import { OBSConnection } from './connection.js';
import { RecorderConfig, RecorderState } from './types.js';
import { logger } from './logger.js';
import { mkdir, readdir, stat } from 'fs/promises';
import path from 'path';

export class OBSRecorder {
  private connection: OBSConnection;
  private state: RecorderState = {
    isRecording: false,
    recordingStartTime: null,
    splitCount: 0,
  };
  private fileWatcherInterval: NodeJS.Timeout | null = null;
  private seenFiles = new Set<string>();

  constructor(private config: RecorderConfig) {
    this.connection = new OBSConnection(
      config.obsWebSocketUrl,
      config.obsWebSocketPassword
    );
  }

  async start(): Promise<void> {
    if (this.state.isRecording) {
      throw new Error('Recording already in progress');
    }

    try {
      // 1. Connect to OBS
      logger.info('Connecting to OBS...');
      await this.connection.connect();

      // 2. Create output directory
      logger.info(`Creating output directory: ${this.config.outputDir}`);
      await mkdir(this.config.outputDir, { recursive: true });

      // 3. Start recording
      logger.info('Starting OBS recording...');
      await this.connection.call('StartRecord');

      // 4. Setup state
      this.state.isRecording = true;
      this.state.recordingStartTime = new Date();

      // 5. Start file watcher
      this.startFileWatcher();

      // 6. Setup event listeners
      this.setupEventListeners();

      logger.info(
        `Recording started continuously to ${this.config.outputDir}`
      );
    } catch (error) {
      this.state.isRecording = false;
      logger.error('Failed to start recording:', error);
      throw error;
    }
  }

  async stop(): Promise<void> {
    if (!this.state.isRecording) {
      throw new Error('No recording in progress');
    }

    try {
      // 1. Stop recording
      logger.info('Stopping OBS recording...');
      await this.connection.call('StopRecord');

      // 2. Stop file watcher
      this.stopFileWatcher();

      // 3. Disconnect from OBS
      logger.info('Disconnecting from OBS...');
      await this.connection.disconnect();

      // 4. Update state
      this.state.isRecording = false;

      logger.info('Recording stopped');
    } catch (error) {
      logger.error('Error during stop:', error);
      throw error;
    }
  }

  isRecording(): boolean {
    return this.state.isRecording;
  }

  private startFileWatcher(): void {
    logger.debug('Starting file watcher...');

    this.fileWatcherInterval = setInterval(async () => {
      try {
        const files = await readdir(this.config.outputDir);

        for (const file of files) {
          // Look for audio files (MP3 or other formats OBS creates)
          if (
            (file.endsWith('.mp3') ||
              file.endsWith('.m4a') ||
              file.endsWith('.wav')) &&
            !this.seenFiles.has(file)
          ) {
            const filePath = path.join(this.config.outputDir, file);

            try {
              const stats = await stat(filePath);
              if (stats.isFile()) {
                this.seenFiles.add(file);
                console.log(`✓ Audio file created: ${file}`);
                logger.info(`Audio file created: ${file}`);
              }
            } catch (error) {
              logger.debug(`Error checking file ${file}:`, error);
            }
          }
        }
      } catch (error) {
        logger.debug('Error monitoring output directory:', error);
      }
    }, 500); // Check every 500ms
  }

  private stopFileWatcher(): void {
    if (this.fileWatcherInterval) {
      clearInterval(this.fileWatcherInterval);
      this.fileWatcherInterval = null;
      logger.debug('File watcher stopped');
    }
  }

  private setupEventListeners(): void {
    // Listen for recording state changes
    this.connection.on('RecordStateChanged', (event: any) => {
      logger.debug('RecordStateChanged event:', event);

      if (event.outputActive) {
        logger.info('Recording is active');
      } else {
        logger.warn('Recording became inactive');
      }
    });

    // Listen for record file changed
    this.connection.on('RecordFileChanged', (event: any) => {
      logger.debug('RecordFileChanged event:', event);

      if (event.recordFilename) {
        logger.info(`Recording file changed: ${event.recordFilename}`);
      }
    });

    // Listen for general event
    this.connection.on('ExitStarted', () => {
      logger.warn('OBS is shutting down');
    });
  }
}
