'use client'

import clsx from 'clsx'

interface StatusDisplayProps {
  isRecording: boolean
  currentFiles: string[]
}

export default function StatusDisplay({
  isRecording,
  currentFiles,
}: StatusDisplayProps) {
  return (
    <div className="bg-gray-800 rounded-lg p-6 space-y-4 shadow-lg">
      <div className="flex items-center justify-between">
        <span className="text-gray-400">Status:</span>
        <span
          className={clsx(
            'font-semibold text-sm',
            isRecording ? 'text-green-400' : 'text-gray-500'
          )}
        >
          {isRecording ? 'On' : 'Off'}
        </span>
      </div>

      {/* <div className="flex items-center justify-between">
        <span className="text-gray-400">Queue:</span>
        <span className="font-semibold text-sm">{queueLength} files</span>
      </div> */}

      {currentFiles.length > 0 && (
        <div className="pt-4 border-t border-gray-700">
          <span className="text-gray-400 text-xs block mb-1">
            Processing ({currentFiles.length}):
          </span>
          <div className="space-y-1">
            {currentFiles.map((file, idx) => (
              <p
                key={idx}
                className="text-xs font-mono truncate bg-gray-900 p-2 rounded text-blue-400"
              >
                {file}
              </p>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
