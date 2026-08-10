'use client'

import { useAppStore } from '../stores/appStore'
import { useTranscriptionEvents } from '../hooks/useEventListener'
import RecordingControls from '../components/RecordingControls'
import StatusDisplay from '../components/StatusDisplay'
import { useEffect, useState } from 'react'

export default function Home() {
  const [mounted, setMounted] = useState(false)
  const { isRecording, currentFiles, error, clearError } = useAppStore()

  useTranscriptionEvents()

  useEffect(() => {
    setMounted(true)
  }, [])

  if (!mounted) {
    return null
  }

  return (
    <main className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900 text-white flex flex-col items-center justify-center p-8">
      <div className="max-w-md w-full space-y-8">
        <div className="text-center">
          <h1 className="text-4xl font-bold mb-2">Rex</h1>
          <p className="text-gray-400 text-sm">
            this is Rex
          </p>
        </div>

        <RecordingControls />

        <StatusDisplay
          isRecording={isRecording}
          currentFiles={currentFiles}
        />

        {error && (
          <div className="bg-red-900/20 border border-red-700 rounded-lg p-4 relative">
            <button
              onClick={clearError}
              className="absolute top-2 right-2 text-red-400 hover:text-red-300 text-lg"
            >
              ×
            </button>
            <p className="text-sm text-red-400">{error}</p>
          </div>
        )}

        <div className="text-xs text-gray-500 text-center pt-4 border-t border-gray-700">
          {/* <p>Audio chunks: 60 seconds</p>
          <p>Parallel processing via AWS Whisper API</p> */}
        </div>
      </div>
    </main>
  )
}
