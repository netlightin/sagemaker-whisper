# Audio Transcriber

Transcribes audio files from a pending directory using a remote API endpoint with automatic retry logic and concurrent processing.

## Prerequisites

- Node.js 18+
- Access to the transcription API endpoint

## Installation

```bash
npm install
cp .env.example .env
npm run build
```

## Configuration

Edit `.env` to customize:

- `PENDING_DIR`: Directory to watch for audio files (default: /Users/raer/Documents/code/ncapi/stuff/sagemaker-whisper/recorder/pending)
- `PROCESSED_AUDIO_DIR`: Directory to move processed audio files (default: ./processed/audio)
- `PROCESSED_TRANSCRIPT_DIR`: Directory to save transcripts (default: ./processed/transcribed)
- `API_ENDPOINT`: Transcription API endpoint
- `API_KEY`: API key for authentication
- `API_TIMEOUT`: Request timeout in milliseconds (default: 300000 = 5 minutes)
- `MAX_RETRIES`: Maximum retry attempts (default: 3)
- `NUM_WORKERS`: Number of concurrent workers (default: 2)
- `POLL_INTERVAL`: File polling interval in milliseconds (default: 500)
- `MIN_FILE_SIZE`: Minimum file size to process in bytes (default: 100000 = 100KB)
- `STABILIZATION_DELAY`: Delay after file detection to ensure it's fully written (ms, default: 100)
- `LOG_LEVEL`: Log level - debug, info, warn, error (default: info)

## Usage

```bash
npm start start
```

The transcriber will:
1. Poll the pending directory every 500ms
2. Detect MP3 files larger than 100KB
3. Wait 100ms for file stabilization (to ensure FFmpeg finished writing)
4. Send files to the transcription API
5. Retry failed transcriptions with exponential backoff (2s, 4s, 8s)
6. Move processed audio to `processed/audio/`
7. Save transcripts to `processed/transcribed/`

## File Processing

**Input**: `{PENDING_DIR}/chunk_DD_MM_YYYY__HH_MM_SS.mp3`

**Output**:
- Audio: `processed/audio/chunk_DD_MM_YYYY__HH_MM_SS.mp3`
- Transcript: `processed/transcribed/chunk_DD_MM_YYYY__HH_MM_SS.txt`

## Worker Pool & Retry Logic

- **Concurrent workers**: 2 (configurable via `NUM_WORKERS`)
- **Max retries**: 3
- **Exponential backoff**: 2^n seconds
  - Attempt 1: Immediate
  - Attempt 2: 2 seconds
  - Attempt 3: 4 seconds
  - Attempt 4: 8 seconds (then fails permanently)

## Logging

Logs are output to:
- Console (formatted, real-time)
- `transcriber.log` (file, persistent)

Status updates are logged every 30 seconds showing:
- Queue size (files waiting)
- Worker statistics (processed, failed, current file)

## Development

```bash
npm run dev
```

Watches for changes and rebuilds automatically.

## Production Deployment

### Using PM2

```bash
npm install -g pm2

pm2 start /Users/raer/Documents/code/ncapi/stuff/sagemaker-whisper/transcriber/dist/index.js \
  --name transcriber -- start

pm2 logs transcriber
pm2 status
```

### Auto-restart on System Boot

```bash
pm2 startup
pm2 save
```

## Troubleshooting

### Files not being detected
- Check `PENDING_DIR` path exists and contains MP3 files
- Verify files are larger than `MIN_FILE_SIZE` (default 100KB)
- Check logs for polling errors

### Transcription failures
- Verify API endpoint is accessible
- Check API key is correct
- Review error messages in logs
- Ensure network connectivity

### High memory usage
- Reduce `NUM_WORKERS` to process fewer files concurrently
- Increase `POLL_INTERVAL` to scan less frequently
