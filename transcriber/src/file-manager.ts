import { rename, writeFile, mkdir, stat } from 'fs/promises';
import path from 'path';
import { TranscriberConfig } from './types.js';
import { logger } from './logger.js';

export class FileManager {
  constructor(private config: TranscriberConfig) {}

  async initialize(): Promise<void> {
    await mkdir(this.config.processedAudioDir, { recursive: true });
    await mkdir(this.config.processedTranscriptDir, { recursive: true });
    logger.info('Directories initialized');
  }

  async saveTranscript(audioFilePath: string, transcript: string): Promise<void> {
    const fileName = path.basename(
      audioFilePath,
      path.extname(audioFilePath)
    );
    const transcriptPath = path.join(
      this.config.processedTranscriptDir,
      `${fileName}.txt`
    );

    await writeFile(transcriptPath, transcript, 'utf-8');
    logger.info(`Transcript saved: ${transcriptPath}`);
  }

  async moveToProcessed(audioFilePath: string): Promise<void> {
    const fileName = path.basename(audioFilePath);
    const destination = path.join(this.config.processedAudioDir, fileName);

    await rename(audioFilePath, destination);
    logger.info(`Audio file moved: ${destination}`);
  }

  async isFileReady(filePath: string): Promise<boolean> {
    try {
      const stats = await stat(filePath);
      return stats.size >= this.config.minFileSize;
    } catch {
      return false;
    }
  }
}
