'use client';

import { useState } from 'react';
import AudioUpload from '@/components/AudioUpload';
import TranscriptionResult from '@/components/TranscriptionResult';
import LoadingSpinner from '@/components/LoadingSpinner';
import { apiClient, TranscriptionResponse } from '@/lib/api';

export default function Home() {
  const [isUploading, setIsUploading] = useState(false);
  const [result, setResult] = useState<TranscriptionResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [fileName, setFileName] = useState<string>('');

  const handleFileSelect = async (file: File) => {
    setIsUploading(true);
    setError(null);
    setResult(null);
    setFileName(file.name);

    try {
      const transcription = await apiClient.transcribeAudio(file);
      setResult(transcription);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred during transcription');
    } finally {
      setIsUploading(false);
    }
  };

  const handleReset = () => {
    setResult(null);
    setError(null);
    setFileName('');
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <div className="container mx-auto px-4 py-12">
        <header className="text-center mb-12">
          <h1 className="text-5xl font-bold text-gray-900 mb-4">
            Whisper Transcription
          </h1>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            Upload your audio files and get accurate transcriptions powered by OpenAI Whisper Large V3 Turbo
          </p>
        </header>

        {!result && !isUploading && (
          <AudioUpload onFileSelect={handleFileSelect} isUploading={isUploading} />
        )}

        {isUploading && <LoadingSpinner />}

        {error && (
          <div className="w-full max-w-2xl mx-auto mt-8">
            <div className="bg-red-50 border-2 border-red-200 rounded-lg p-6">
              <div className="flex items-start">
                <svg
                  className="w-6 h-6 text-red-600 mt-0.5 mr-3"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <div>
                  <h3 className="text-lg font-semibold text-red-800 mb-1">
                    Transcription Failed
                  </h3>
                  <p className="text-red-700">{error}</p>
                </div>
              </div>
              <button
                onClick={handleReset}
                className="mt-4 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors"
              >
                Try Again
              </button>
            </div>
          </div>
        )}

        {result && (
          <>
            <TranscriptionResult result={result} fileName={fileName} />
            <div className="text-center mt-8">
              <button
                onClick={handleReset}
                className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors shadow-lg"
              >
                Transcribe Another File
              </button>
            </div>
          </>
        )}

        <footer className="text-center mt-16 text-gray-600">
          <p className="text-sm">
            Powered by AWS SageMaker and OpenAI Whisper Large V3 Turbo
          </p>
        </footer>
      </div>
    </div>
  );
}
