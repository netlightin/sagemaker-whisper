import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config();

export const config = {
  pendingDir:
    process.env.PENDING_DIR ||
    '/Users/raer/Documents/code/ncapi/stuff/sagemaker-whisper/recorder/pending',
  processedAudioDir:
    process.env.PROCESSED_AUDIO_DIR ||
    path.join(__dirname, '..', 'processed', 'audio'),
  processedTranscriptDir:
    process.env.PROCESSED_TRANSCRIPT_DIR ||
    path.join(__dirname, '..', 'processed', 'transcribed'),
  apiEndpoint:
    process.env.API_ENDPOINT ||
    'http://loud-meadow-alb-235533752.eu-west-1.elb.amazonaws.com/transcribe',
  apiKey:
    process.env.API_KEY || 'e20ce61a459e49ed9319ceab0f72b5d1',
  maxRetries: parseInt(process.env.MAX_RETRIES || '3'),
  numWorkers: parseInt(process.env.NUM_WORKERS || '2'),
  pollInterval: parseInt(process.env.POLL_INTERVAL || '500'),
  minFileSize: parseInt(process.env.MIN_FILE_SIZE || '100000'),
  stabilizationDelay: parseInt(process.env.STABILIZATION_DELAY || '100'),
  apiTimeout: parseInt(process.env.API_TIMEOUT || '300000'),
};
