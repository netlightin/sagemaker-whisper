import { ChildProcess } from 'child_process';

export interface RecorderConfig {
  chunkDuration: number;
  outputDir: string;
  audioDeviceIndex: number;
}

export interface RecorderState {
  isRecording: boolean;
  process: ChildProcess | null;
  startTime: Date | null;
}
