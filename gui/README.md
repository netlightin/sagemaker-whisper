# Audio Transcriber

A desktop application that continuously records system audio and microphone input, saves audio in 60-second MP3 chunks, and automatically transcribes them using AWS Whisper API.

## Features

- **Dual Audio Recording**: Captures both system audio and microphone input simultaneously
- **Automatic Chunking**: Saves audio in 60-second MP3 chunks to the `/pending` folder
- **Sequential Processing**: Transcribes audio files one at a time using AWS Whisper API
- **Dark Theme UI**: Clean, dark-themed interface with ON/OFF controls
- **Real-time Status**: See recording status, queue length, and current processing file
- **Error Handling**: Retry logic with exponential backoff for failed transcriptions

## Prerequisites

### System Requirements

- macOS 12.0 or later
- 4GB RAM minimum
- 500MB free disk space

### Software Requirements

1. **Node.js** (v18.0.0 or later)
   ```bash
   brew install node
   ```

2. **FFmpeg** (for audio recording)
   ```bash
   brew install ffmpeg
   ```

3. **BlackHole** (for system audio capture)
   ```bash
   brew install blackhole-2ch
   ```

### Audio Device Setup (macOS Audio MIDI Setup)

After installing BlackHole, you need to configure macOS audio routing:

1. Open **Audio MIDI Setup** (⌘+Space → type "Audio MIDI Setup")

2. **Create Multi-Output Device** (for hearing system audio):
   - Click the '+' button at the bottom left
   - Select "Create Multi-Output Device"
   - Check boxes for:
     - ☑️ BlackHole 2ch
     - ☑️ Built-in Output
   - Name: "Multi-Output Device" (or any name)

3. **Create Aggregate Device** (for recording both):
   - Click the '+' button again
   - Select "Create Aggregate Device"
   - Check boxes for:
     - ☑️ BlackHole 2ch
     - ☑️ Built-in Microphone
   - **Important**: Name this exactly **"Transcription Aggregate"**

4. **(Optional) Set as default input**:
   - System Settings → Sound → Input → Select "Transcription Aggregate"

**Automated Setup**: Run the setup script to check prerequisites:
```bash
./scripts/setup-audio.sh
```

## Installation

1. **Clone/Install the app**:
   ```bash
   cd /Users/raer/Documents/code/ncapi/stuff/sagemaker-whisper/gui
   npm install
   ```

2. **Verify audio setup** (see Prerequisites section above)

## Running the App

### Development Mode

```bash
npm run tauri dev
```

This starts the Next.js development server and Tauri in watch mode.

### Building for Production

```bash
npm run tauri build
```

This creates a macOS app bundle in `src-tauri/target/release/bundle/macos/`

## Usage

1. **Start the app**:
   ```bash
   npm run tauri dev
   ```

2. **Click ON button**:
   - FFmpeg starts recording from your configured audio devices
   - 60-second chunks are saved to `~/Library/Application Support/audio-transcriber/pending/`

3. **Listen/Speak**:
   - System audio and microphone input are recorded
   - Continue using your computer normally

4. **Automatic Processing**:
   - Each completed chunk is automatically transcribed
   - Transcriptions save to `~/Library/Application Support/audio-transcriber/processed/transcripts/`
   - Audio files move to `~/Library/Application Support/audio-transcriber/processed/audio/`

5. **Click OFF button**:
   - Recording stops
   - Remaining queued files finish processing
   - App waits for all transcriptions to complete

## File Organization

```
~/Library/Application Support/audio-transcriber/
├── pending/                           # Recording in progress
│   ├── chunk_20260810_100000.mp3
│   ├── chunk_20260810_100100.mp3
│   └── ...
└── processed/                         # Completed processing
    ├── audio/                         # Archived audio files
    │   ├── chunk_20260810_100000.mp3
    │   └── ...
    └── transcripts/                   # Transcription text files
        ├── chunk_20260810_100000.txt
        └── ...
```

## Troubleshooting

### "BlackHole device not found"

**Problem**: FFmpeg fails with "device not found"

**Solution**:
1. Verify BlackHole is installed: `ls /Library/Audio/Plug-Ins/HAL/`
2. Restart Audio MIDI Setup app
3. Restart your computer
4. Check that "Transcription Aggregate" is named exactly (no typos)

### "Permission denied" for microphone

**Problem**: App can't access microphone

**Solution**:
1. System Settings → Privacy & Security → Microphone
2. Find "Audio Transcriber" and allow access
3. Restart the app

### Recording starts but no audio chunks appear

**Problem**: FFmpeg is running but not creating files

**Solution**:
1. Check device names match Audio MIDI Setup: `ffmpeg -f avfoundation -list_devices short`
2. Verify "Transcription Aggregate" exists and is properly configured
3. Check disk space: `df -h`
4. Check app data directory permissions: `ls -la ~/Library/Application\ Support/audio-transcriber/`

### Transcription fails with API error

**Problem**: "API error 401" or similar

**Possible causes**:
- API key expired or invalid
- Network connection issue
- API endpoint unreachable

**Solution**:
1. Check internet connection
2. Verify AWS endpoint is accessible: `curl http://loud-meadow-alb-235533752.eu-west-1.elb.amazonaws.com/transcribe`
3. Check API key in `.env.local` file
4. Check logs: `less ~/Library/Application\ Support/audio-transcriber/logs/`

### Slow transcription processing

**Problem**: Transcriptions are slow or timing out

**Solution**:
- AWS Whisper API has a 5-minute timeout per file
- 60-second MP3 chunks should process within a few seconds
- If slow: Check network bandwidth, API load, or AWS service status

## Architecture

### Frontend (React + Next.js + Tauri)
- **UI Components**: Recording controls and status display
- **State Management**: Zustand store for app state
- **Event Listeners**: Real-time updates from backend

### Backend (Rust + Tokio)
- **Audio Recorder**: FFmpeg process management with segment muxer
- **File Watcher**: Monitors `/pending` for new audio files
- **Transcription Queue**: FIFO queue for sequential API calls
- **API Client**: Handles multipart HTTP uploads to AWS

## Configuration

Edit `.env.local` to customize:

```bash
WHISPER_API_KEY=your-api-key-here
WHISPER_API_URL=http://your-api-endpoint.com/transcribe
```

### Advanced Configuration

To change chunk duration (in Rust code):
- Edit `src-tauri/src/services/audio_recorder.rs`
- Change `segment_time` value (in seconds)
- Rebuild with `npm run tauri build`

## Performance

### System Overhead
- **CPU**: 5-15% (FFmpeg encoding) + 2-5% (app idle)
- **Memory**: ~150-200MB
- **Disk**: ~1-2MB per minute of audio (MP3 128k bitrate)

### Recording Duration
- **Max continuous**: Limited by disk space
- **Typical**: Can run 24/7 with auto-cleanup (future feature)

## Security

- API key stored in `.env.local` (excluded from git)
- No data sent except to AWS Whisper API
- All transcriptions stored locally in `~/Library/Application Support/`

## Development

### Project Structure
```
src-tauri/src/
├── main.rs                 # Tauri app entry point
├── lib.rs                  # Module definitions
├── errors.rs               # Error types
├── models/                 # Data structures
├── services/               # Core business logic
│   ├── audio_recorder.rs
│   ├── file_watcher.rs
│   ├── api_client.rs
│   └── transcription_queue.rs
└── commands/               # Tauri command handlers

src/
├── app/
│   ├── page.tsx            # Main UI page
│   ├── layout.tsx          # Root layout
│   └── globals.css         # Global styles
├── components/
│   ├── RecordingControls.tsx
│   ├── StatusDisplay.tsx
│   └── ...
├── hooks/
│   ├── useEventListener.ts
│   └── ...
└── stores/
    └── appStore.ts         # Zustand state store
```

### Building from Source

1. **Install dependencies**:
   ```bash
   npm install
   cargo build -p audio-transcriber
   ```

2. **Run development server**:
   ```bash
   npm run tauri dev
   ```

3. **Build release binary**:
   ```bash
   npm run tauri build
   ```

## Known Issues

1. **Audio Device Names**: Different macOS versions may have different device names. Check with:
   ```bash
   ffmpeg -f avfoundation -list_devices short
   ```

2. **Aggregate Device Persistence**: Audio MIDI Setup devices may reset after restart. Keep the configuration saved.

3. **Long Recording Sessions**: FFmpeg may accumulate memory over 12+ hours. Periodic restart recommended.

## Future Enhancements

- [ ] Configurable chunk duration in UI
- [ ] Real-time transcript display
- [ ] Audio playback in app
- [ ] Export transcripts (combine all into one file)
- [ ] Automatic cleanup of old files
- [ ] Failed transcription retry UI
- [ ] Dark/light theme toggle
- [ ] System tray integration
- [ ] Support for other audio APIs (local Whisper, etc.)

## Support

For issues, check:
1. The troubleshooting section above
2. System logs: `~/Library/Application\ Support/audio-transcriber/`
3. FFmpeg compatibility with your macOS version

## License

Proprietary - Internal Use Only

## Credits

Built with:
- [Tauri](https://tauri.app/) - Desktop app framework
- [Next.js](https://nextjs.org/) - React framework
- [FFmpeg](https://ffmpeg.org/) - Audio processing
- [BlackHole](https://github.com/ExistentialAudio/BlackHole) - Virtual audio device
- [AWS Whisper](https://aws.amazon.com/transcribe/) - Speech-to-text API
