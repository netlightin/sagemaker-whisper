# Audio Recorder

Records audio in chunks using FFmpeg with professional audio quality settings.

## Prerequisites

- Node.js 18+
- FFmpeg with avfoundation support (macOS)
  ```bash
  brew install ffmpeg
  ffmpeg -f avfoundation -list_devices true -i ""
  ```

## Installation

```bash
npm install
cp .env.example .env
npm run build
```

## Usage

```bash
# Start recording
npm start start

# Or with custom chunk duration (in seconds)
npm start start -- --duration 120

# Press Ctrl+C to stop
```

## Configuration

Edit `.env` to customize:

- `CHUNK_DURATION`: Duration of each audio chunk in seconds (default: 60)
- `OUTPUT_DIR`: Directory for output chunks (default: ./pending)
- `AUDIO_DEVICE_INDEX`: Audio device index (default: 0 for built-in mic)
- `LOG_LEVEL`: Log level - debug, info, warn, error (default: info)

## Output

Audio chunks are saved to `./pending/` with filename format:
```
chunk_DD_MM_YYYY__HH_MM_SS.mp3
```

Example: `chunk_11_08_2026__09_30_45.mp3`

Each file is approximately 320 kbps MP3 with professional audio filters applied:
- Highpass filter at 150Hz (removes wind noise)
- Audio noise reduction
- Lowpass filter at 12kHz
- 3x volume boost
- Loudness normalization to broadcast standards

## Development

```bash
npm run dev
```

Watches for changes and rebuilds automatically.
