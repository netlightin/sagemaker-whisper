'use client';

import { TranscriptionResponse } from '@/lib/api';

interface TranscriptionResultProps {
  result: TranscriptionResponse;
  fileName: string;
}

export default function TranscriptionResult({ result, fileName }: TranscriptionResultProps) {
  const downloadAsText = () => {
    const blob = new Blob([result.text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${fileName.replace(/\.[^/.]+$/, '')}_transcription.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const downloadAsJSON = () => {
    const blob = new Blob([JSON.stringify(result, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${fileName.replace(/\.[^/.]+$/, '')}_transcription.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(result.text);
  };

  return (
    <div className="w-full max-w-4xl mx-auto mt-8">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="flex justify-between items-center mb-4">
          <h2 className="text-2xl font-bold text-gray-800">Transcription Result</h2>
          <div className="flex gap-2">
            <button
              onClick={copyToClipboard}
              className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg transition-colors"
            >
              Copy
            </button>
            <button
              onClick={downloadAsText}
              className="px-4 py-2 bg-blue-100 hover:bg-blue-200 text-blue-700 rounded-lg transition-colors"
            >
              Download TXT
            </button>
            <button
              onClick={downloadAsJSON}
              className="px-4 py-2 bg-green-100 hover:bg-green-200 text-green-700 rounded-lg transition-colors"
            >
              Download JSON
            </button>
          </div>
        </div>

        <div className="mb-4 flex gap-4 text-sm text-gray-600">
          <div>
            <span className="font-semibold">File:</span> {fileName}
          </div>
          {result.language && (
            <div>
              <span className="font-semibold">Language:</span> {result.language}
            </div>
          )}
          {result.duration && (
            <div>
              <span className="font-semibold">Duration:</span> {result.duration.toFixed(2)}s
            </div>
          )}
        </div>

        <div className="bg-gray-50 rounded-lg p-6 border border-gray-200">
          <p className="text-gray-800 whitespace-pre-wrap leading-relaxed">{result.text}</p>
        </div>
      </div>
    </div>
  );
}
