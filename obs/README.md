# OBS WebSocket Audio Recorder

Records audio via OBS WebSocket in one continuous file.

## Prerequisites

- Node.js 18+
- OBS Studio installed and running
- obs-websocket plugin enabled in OBS (Tools > obs-websocket Settings)
- OBS configured for audio recording

## Installation

```bash
npm install
cp .env.example .env
npm run build
```

## Configuration

### Environment Variables (.env)

Edit `.env` to customize:

- `OUTPUT_DIR`: Directory for recordings (default: ./pending)
- `OBS_WEBSOCKET_URL`: OBS WebSocket address (default: ws://127.0.0.1:4455)
- `OBS_WEBSOCKET_PASSWORD`: OBS WebSocket password
- `LOG_LEVEL`: Log level - debug, info, warn, error (default: info)

### OBS Configuration

Before running the recorder, configure OBS:

#### 1. Enable WebSocket (Tools > obs-websocket Settings)
- **Enable WebSocket server**: Checked
- **Server Port**: 4455 (or your configured port)
- **Enable Authentication**: Checked
- **Password**: Set a strong password (copy to `.env` as `OBS_WEBSOCKET_PASSWORD`)

#### 2. Recording Settings (Settings > Output > Recording)
- **Output Mode**: Advanced
- **Type**: Standard
- **Recording Format**: MP3 (or other audio format)
- **Audio Bitrate**: 320 kbps (recommended)
- **Recording Path**: Set to match `OUTPUT_DIR` from `.env`
- **Enable Automatic File Splitting**: Disabled (optional - not used by this recorder)

#### 3. Audio Settings (Settings > Audio)
- **Sample Rate**: 48 kHz (recommended)
- **Channels**: Stereo (or Mono)

#### 4. Audio Filters (optional, on Audio Source)
Configure audio filters on your audio input source in OBS:
- **High-Pass Filter**: 150 Hz cutoff (removes rumble)
- **Low-Pass Filter**: 12000 Hz cutoff (removes noise)
- **Noise Suppression**: RNNoise or Speex (optional)
- **Compressor**: For dynamic range (optional)
- **Gain**: +9.5 dB for volume boost (optional)

## Usage

### Start Recording

```bash
npm run start -- start
```

The recorder will:
1. Connect to OBS via WebSocket
2. Start recording continuously to a single file
3. Monitor the output directory
4. Log when the recording file is created

### Stop Recording

```bash
npm run start -- stop
```

Or press Ctrl+C for graceful shutdown.

## How It Works

1. **Connects to OBS**: Via WebSocket at configured URL/password
2. **Starts Recording**: Issues StartRecord command to OBS
3. **Continuous Recording**: Records all audio to a single file
4. **Monitors Output**: Watches output directory for the recording file
5. **Graceful Stop**: Stops recording when you press Ctrl+C or run the `stop` command

## File Output

Recording files are created in the `OUTPUT_DIR` with OBS's default naming pattern. The exact filename depends on OBS's configured naming template.

Example output:
```
./pending/
  └── recording_2024-08-12_10-30-00.mp3  (grows continuously until stopped)
```

## Logging

Logs are output to:
- Console (formatted, real-time)
- `obs-recorder.log` (file, persistent)

## Development

Watch for changes and rebuild automatically:

```bash
npm run dev
```

## Production Deployment

### Using PM2

```bash
npm install -g pm2

pm2 start dist/index.js \
  --name obs-recorder -- start

pm2 logs obs-recorder
pm2 status
```

### Auto-restart on System Boot

```bash
pm2 startup
pm2 save
```

## Troubleshooting

### OBS WebSocket Connection Failed
- **Error**: "OBS is not running or WebSocket is not enabled"
- **Solution**:
  - Make sure OBS is running
  - Enable WebSocket: Tools > obs-websocket Settings > Enable WebSocket server
  - Check the port matches `OBS_WEBSOCKET_URL` in `.env`

### Authentication Failed
- **Error**: "Authentication failed. Check OBS_WEBSOCKET_PASSWORD"
- **Solution**:
  - Verify the password in `.env` matches OBS WebSocket password
  - Re-enter password in OBS settings if needed

### No Audio Files Appearing
- **Check**:
  - OBS is actively recording (red dot indicator in OBS)
  - `OUTPUT_DIR` path is correct in `.env`
  - Recording path in OBS matches `OUTPUT_DIR`
  - Check `obs-recorder.log` for errors

### Connection Lost During Recording
- **Behavior**: Recorder automatically attempts to reconnect
- **Recovery**: Reconnection uses exponential backoff (1s, 2s, 4s, up to 30s)
- **Note**: OBS continues recording even if connection drops

## Comparison with FFmpeg Recorder

### Advantages
- No need for direct audio device access
- Can record from any OBS source (multiple mics, desktop audio, etc.)
- Visual feedback via OBS interface
- Hardware encoding support
- Easier audio routing configuration

### Disadvantages
- Requires OBS to be running
- Audio filters must be pre-configured
- File naming controlled by OBS
- Additional setup (OBS configuration)

## Differences from FFmpeg Version

| Aspect | FFmpeg | OBS |
|--------|--------|-----|
| Audio Source | AVFoundation device | OBS configured source |
| Recording Style | Automatic chunking via segment | Continuous single file |
| Filters | Applied during recording | Pre-configured in OBS |
| Format | Directly MP3 | Configured in OBS |
| Naming | Timestamp pattern | OBS pattern |
| Runtime Control | Yes (via ffmpeg args) | Limited (WebSocket API) |

## Performance

- **CPU**: Depends on OBS encoder settings (hardware encoding recommended)
- **Memory**: Minimal WebSocket connection overhead
- **Disk I/O**: Continuous streaming to configured output directory

## Advanced: Custom Audio Filters

Configure audio filters directly in OBS for more advanced processing:

1. In OBS, right-click your audio source
2. Select "Filters"
3. Add filters in this order:
   - High-Pass Filter (150 Hz)
   - Noise Suppression (RNNoise)
   - Low-Pass Filter (12000 Hz)
   - Compressor (Ratio 2:1, Attack 10ms, Release 100ms)
   - Limiter (Threshold -3dB)
   - Gain (+9.5 dB)

Adjust settings to match your microphone and environment.

## Support

For issues with the recorder:
1. Check `obs-recorder.log` for error details
2. Verify OBS configuration matches Prerequisites section
3. Review troubleshooting section above

For OBS WebSocket issues:
- See https://github.com/obs-websocket-community-projects/obs-websocket-js
- OBS WebSocket documentation: https://github.com/obsproject/obs-websocket
