import axios, { AxiosInstance } from 'axios';
import FormData from 'form-data';
import { createReadStream } from 'fs';
import { TranscriberConfig, TranscriptionResult } from './types.js';
import { logger } from './logger.js';

export class ApiClient {
  private client: AxiosInstance;

  constructor(private config: TranscriberConfig) {
    this.client = axios.create({
      timeout: config.apiTimeout,
      headers: {
        'x-api-key': config.apiKey,
      },
    });
  }

  async transcribeAudio(filePath: string): Promise<string> {
    const form = new FormData();
    form.append('audio', createReadStream(filePath));

    logger.info(`Sending transcription request for: ${filePath}`);

    try {
      const response = await this.client.post<TranscriptionResult>(
        this.config.apiEndpoint,
        form,
        {
          headers: {
            ...form.getHeaders(),
          },
        }
      );

      if (!response.data.text) {
        throw new Error('Response missing text field');
      }

      logger.info(`Transcription successful for: ${filePath}`);
      return response.data.text;
    } catch (error) {
      if (axios.isAxiosError(error)) {
        const status = error.response?.status;
        const body = error.response?.data;
        throw new Error(`API error ${status}: ${JSON.stringify(body)}`);
      }
      throw error;
    }
  }
}
