import { spawn, ChildProcess } from 'child_process';
import { mkdir, readdir, stat } from 'fs/promises';
import path from 'path';
import { RecorderConfig, RecorderState } from './types.js';
import { logger } from './logger.js';

export class AudioRecorder {
  private state: RecorderState = {
    isRecording: false,
    process: null,
    startTime: null,
  };
  private seenFiles = new Set<string>();
  private fileWatcherInterval: NodeJS.Timeout | null = null;

  constructor(private config: RecorderConfig) {}

  async start(): Promise<void> {
    if (this.state.isRecording) {
      throw new Error('Recording already in progress');
    }

    // Create output directory
    await mkdir(this.config.outputDir, { recursive: true });

    const outputPath = path.join(
      this.config.outputDir,
      'chunk_%d_%m_%Y__%H_%M_%S.mp3'
    );

    const ffmpegArgs = [
      '-f', 'avfoundation',
      '-audio_device_index', this.config.audioDeviceIndex.toString(),
      '-i', 'none',
      '-af', 'highpass=f=150,anlmdn,lowpass=f=12000,volume=3.0,loudnorm=I=-16:TP=-1.5:LRA=11',
      '-codec:a', 'libmp3lame',
      '-b:a', '320k',
      '-q:a', '0',
      '-f', 'segment',
      '-segment_time', this.config.chunkDuration.toString(),
      '-segment_format', 'mp3',
      '-strftime', '1',
      '-reset_timestamps', '1',
      outputPath,
    ];

    const process = spawn('ffmpeg', ffmpegArgs, {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    process.stdout?.on('data', (data) => {
      logger.debug(`FFmpeg stdout: ${data}`);
    });

    process.stderr?.on('data', (data) => {
      logger.debug(`FFmpeg stderr: ${data}`);
    });

    process.on('error', (error) => {
      logger.error('FFmpeg process error:', error);
      this.state.isRecording = false;
      this.state.process = null;
    });

    process.on('exit', (code, signal) => {
      logger.info(`FFmpeg exited with code ${code}, signal ${signal}`);
      this.state.isRecording = false;
      this.state.process = null;
    });

    this.state.process = process;
    this.state.isRecording = true;
    this.state.startTime = new Date();

    logger.info(
      `Recording started with ${this.config.chunkDuration}s chunks to ${this.config.outputDir}`
    );

    // Start monitoring for new files
    this.startFileWatcher();
  }

  private startFileWatcher(): void {
    this.fileWatcherInterval = setInterval(async () => {
      try {
        const files = await readdir(this.config.outputDir);
        for (const file of files) {
          if (file.endsWith('.mp3') && !this.seenFiles.has(file)) {
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
        logger.debug('Error monitoring pending directory:', error);
      }
    }, 500); // Check every 500ms
  }

  private stopFileWatcher(): void {
    if (this.fileWatcherInterval) {
      clearInterval(this.fileWatcherInterval);
      this.fileWatcherInterval = null;
    }
  }

  async stop(): Promise<void> {
    if (!this.state.isRecording || !this.state.process) {
      throw new Error('No recording in progress');
    }

    // Stop file watcher
    this.stopFileWatcher();

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        logger.warn('FFmpeg did not stop within timeout, force killing');
        this.state.process?.kill('SIGKILL');
        resolve();
      }, 5000);

      this.state.process!.on('exit', () => {
        clearTimeout(timeout);
        logger.info('Recording stopped');
        resolve();
      });

      // Send SIGTERM for graceful shutdown
      this.state.process!.kill('SIGTERM');
    });
  }

  isRecording(): boolean {
    return this.state.isRecording;
  }
}
