import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config();

export const config = {
  chunkDuration: parseInt(process.env.CHUNK_DURATION || '60'),
  outputDir: process.env.OUTPUT_DIR || path.join(__dirname, '..', 'pending'),
  audioDeviceIndex: parseInt(process.env.AUDIO_DEVICE_INDEX || '0'),
  logLevel: process.env.LOG_LEVEL || 'info',
};
