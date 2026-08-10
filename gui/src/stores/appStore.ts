'use client'

import { create } from 'zustand'
import { invoke } from '@tauri-apps/api/core'

export interface QueueStatus {
  is_recording: boolean
  queue_length: number
  current_files: string[]
  last_error: string | null
}

interface AppState {
  isRecording: boolean
  queueLength: number
  currentFiles: string[]
  error: string | null
  chunkDuration: number

  startRecording: () => Promise<void>
  stopRecording: () => Promise<void>
  setChunkDuration: (duration: number) => void
  updateQueueStatus: (status: QueueStatus) => void
  clearError: () => void
}

export const useAppStore = create<AppState>((set) => ({
  isRecording: false,
  queueLength: 0,
  currentFiles: [],
  error: null,
  chunkDuration: 60,

  startRecording: async () => {
    try {
      await invoke('start_recording', { chunkDuration: 60 })
      set({ isRecording: true, error: null })
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : String(error),
      })
    }
  },

  stopRecording: async () => {
    try {
      await invoke('stop_recording')
      set({ isRecording: false })
    } catch (error) {
      set({
        error: error instanceof Error ? error.message : String(error),
      })
    }
  },

  setChunkDuration: (duration) => {
    set({ chunkDuration: duration })
  },

  updateQueueStatus: (status: QueueStatus) => {
    set({
      isRecording: status.is_recording,
      queueLength: status.queue_length,
      currentFiles: status.current_files,
    })
  },

  clearError: () => {
    set({ error: null })
  },
}))
