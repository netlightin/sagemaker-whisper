'use client'

import { useAppStore } from '../stores/appStore'
import clsx from 'clsx'

export default function RecordingControls() {
  const { isRecording, startRecording, stopRecording } = useAppStore()

  return (
    <div className="flex gap-4 justify-center">
      <button
        onClick={startRecording}
        disabled={isRecording}
        className={clsx(
          'px-8 py-4 rounded-lg font-semibold text-lg transition-all',
          'disabled:opacity-50 disabled:cursor-not-allowed',
          !isRecording &&
            'bg-green-600 hover:bg-green-700 active:scale-95 shadow-lg hover:shadow-xl'
        )}
      >
        ON
      </button>

      <button
        onClick={stopRecording}
        disabled={!isRecording}
        className={clsx(
          'px-8 py-4 rounded-lg font-semibold text-lg transition-all',
          'disabled:opacity-50 disabled:cursor-not-allowed',
          isRecording &&
            'bg-red-600 hover:bg-red-700 active:scale-95 shadow-lg hover:shadow-xl'
        )}
      >
        OFF
      </button>
    </div>
  )
}
