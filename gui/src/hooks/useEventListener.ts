'use client'

import { useEffect } from 'react'
import { listen } from '@tauri-apps/api/event'
import { useAppStore } from '../stores/appStore'

export function useTranscriptionEvents() {
  const updateQueueStatus = useAppStore((state) => state.updateQueueStatus)

  useEffect(() => {
    let unlisteners: (() => void)[] = []

    const setupListeners = async () => {
      try {
        const unlistenStart = await listen('transcription:processing', (event) => {
          console.log('Processing:', event.payload)
        })
        unlisteners.push(unlistenStart)

        const unlistenComplete = await listen('transcription:completed', (event) => {
          console.log('Completed:', event.payload)
        })
        unlisteners.push(unlistenComplete)

        const unlistenError = await listen('transcription:error', (event) => {
          console.error('Error:', event.payload)
        })
        unlisteners.push(unlistenError)

        const unlistenStatus = await listen<any>('queue:status', (event) => {
          updateQueueStatus({
            is_recording: false,
            queue_length: event.payload.queue_length,
            current_files: event.payload.current_files,
            last_error: null,
          })
        })
        unlisteners.push(unlistenStatus)
      } catch (error) {
        console.error('Failed to setup event listeners:', error)
      }
    }

    setupListeners()

    return () => {
      unlisteners.forEach((fn) => fn())
    }
  }, [updateQueueStatus])
}
