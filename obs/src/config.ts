import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { RecorderConfig } from './types.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config();

export const config: RecorderConfig = {
  chunkDuration: parseInt(process.env.CHUNK_DURATION || '60'),
  outputDir: process.env.OUTPUT_DIR || path.join(__dirname, '..', 'pending'),
  obsWebSocketUrl: process.env.OBS_WEBSOCKET_URL || 'ws://127.0.0.1:4455',
  obsWebSocketPassword: process.env.OBS_WEBSOCKET_PASSWORD || '',
  logLevel: process.env.LOG_LEVEL || 'info',
};
