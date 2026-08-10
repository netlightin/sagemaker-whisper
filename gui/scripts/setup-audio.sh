#!/bin/bash

set -e

echo "=========================================="
echo "Audio Transcriber Setup"
echo "=========================================="
echo ""

# Check for BlackHole installation
if ! ls /Library/Audio/Plug-Ins/HAL/BlackHole* 2>/dev/null | grep -q BlackHole; then
  echo "❌ BlackHole not found"
  echo ""
  echo "Installing BlackHole 2ch..."
  if ! command -v brew &> /dev/null; then
    echo "❌ Homebrew not installed. Please install Homebrew first:"
    echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
  fi

  brew install blackhole-2ch
  echo "✅ BlackHole installed"
else
  echo "✅ BlackHole already installed"
fi

echo ""
echo "=========================================="
echo "Manual Audio Setup Required"
echo "=========================================="
echo ""
echo "You need to create an Aggregate Audio Device:"
echo ""
echo "1. Open Audio MIDI Setup:"
echo "   - Open Spotlight Search (⌘+Space)"
echo "   - Type 'Audio MIDI Setup'"
echo "   - Press Enter"
echo ""
echo "2. Create a Multi-Output Device (for system audio output):"
echo "   - Click the '+' button in the bottom left"
echo "   - Select 'Create Multi-Output Device'"
echo "   - In the left panel, check these boxes:"
echo "     ☑️ BlackHole 2ch"
echo "     ☑️ Built-in Output"
echo "   - This allows your system audio to be captured AND heard"
echo ""
echo "3. Create an Aggregate Device (for recording):"
echo "   - Click the '+' button again"
echo "   - Select 'Create Aggregate Device'"
echo "   - Check these boxes:"
echo "     ☑️ BlackHole 2ch"
echo "     ☑️ Built-in Microphone"
echo "   - Rename it to: 'Transcription Aggregate'"
echo ""
echo "4. (Optional) Set Transcription Aggregate as default input:"
echo "   - Open System Settings"
echo "   - Go to: Sound"
echo "   - Set 'Transcription Aggregate' as Input device"
echo ""
echo "=========================================="
echo ""
echo "✅ Setup complete!"
echo ""
echo "You can now run the app with: npm run tauri dev"
