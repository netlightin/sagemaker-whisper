import OBSWebSocket from 'obs-websocket-js';
import { createConnection } from 'net';
import { logger } from './logger.js';
import { OBSConnectionState } from './types.js';

export class OBSConnection {
  private obs = new OBSWebSocket();
  private state: OBSConnectionState = {
    isConnected: false,
    obsVersion: null,
    lastConnectionTime: null,
  };
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectDelay = 1000; // Start at 1 second
  private maxReconnectDelay = 30000; // Max 30 seconds
  private reconnectTimeout: NodeJS.Timeout | null = null;
  private eventHandlers = new Map<string, Function[]>();

  constructor(
    private websocketUrl: string,
    private password: string
  ) {
    this.setupEventListeners();
  }

  private setupEventListeners(): void {
    this.obs.on('ConnectionOpened', () => {
      logger.info('OBS WebSocket connection opened');
      this.state.isConnected = true;
      this.state.lastConnectionTime = new Date();
      this.reconnectAttempts = 0;
      this.reconnectDelay = 1000;
    });

    this.obs.on('ConnectionClosed', () => {
      logger.warn('OBS WebSocket connection closed');
      this.state.isConnected = false;
      this.attemptReconnect();
    });

    this.obs.on('ConnectionError', (error: any) => {
      logger.error('OBS WebSocket connection error:', error);
      this.state.isConnected = false;
      this.attemptReconnect();
    });

    this.obs.on('Identified', () => {
      logger.info('OBS WebSocket identified and ready');
    });
  }

  private async healthCheck(): Promise<void> {
    return new Promise((resolve, reject) => {
      const url = new URL(this.websocketUrl);
      const host = url.hostname;
      const port = parseInt(url.port) || 4455;

      const socket = createConnection(
        {
          host,
          port,
          timeout: 5000,
        },
        () => {
          socket.destroy();
          resolve();
        }
      );

      socket.on('error', (error) => {
        logger.debug('Health check failed:', error.message);
        reject(
          new Error(
            `Cannot connect to OBS WebSocket at ${host}:${port}. ` +
              `Make sure OBS is running and WebSocket is enabled in Tools > obs-websocket Settings.`
          )
        );
      });

      socket.on('timeout', () => {
        socket.destroy();
        reject(
          new Error(
            `OBS WebSocket connection timed out at ${host}:${port}. ` +
              `Make sure OBS is running and accessible.`
          )
        );
      });
    });
  }

  async connect(): Promise<void> {
    try {
      // Pre-flight health check
      logger.info('Performing health check on OBS WebSocket...');
      await this.healthCheck();

      // Connect to OBS
      logger.info(`Connecting to OBS WebSocket at ${this.websocketUrl}`);
      const result = await this.obs.connect(
        this.websocketUrl,
        this.password
      );

      logger.info('Successfully connected to OBS');
      if (result?.obsWebSocketVersion) {
        this.state.obsVersion = result.obsWebSocketVersion;
        logger.info(`OBS WebSocket Version: ${result.obsWebSocketVersion}`);
      }
      this.state.isConnected = true;
      this.state.lastConnectionTime = new Date();
      this.reconnectAttempts = 0;
    } catch (error: any) {
      this.state.isConnected = false;

      // Handle authentication errors
      if (error.message?.includes('Authentication') || error.message?.includes('auth')) {
        throw new Error(
          'Authentication failed. Check OBS_WEBSOCKET_PASSWORD in .env'
        );
      }

      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }
    if (this.state.isConnected) {
      await this.obs.disconnect();
      this.state.isConnected = false;
      logger.info('Disconnected from OBS');
    }
  }

  async call(requestType: string, requestData?: any): Promise<any> {
    if (!this.state.isConnected) {
      throw new Error('OBS WebSocket not connected');
    }

    try {
      const response = await (this.obs.call as any)(requestType, requestData);
      return response;
    } catch (error: any) {
      logger.error(`OBS call failed: ${requestType}`, error);
      throw error;
    }
  }

  on(eventType: string, handler: Function): void {
    if (!this.eventHandlers.has(eventType)) {
      this.eventHandlers.set(eventType, []);

      // Setup listener on OBS WebSocket
      (this.obs.on as any)(eventType, (event: any) => {
        const handlers = this.eventHandlers.get(eventType);
        if (handlers) {
          handlers.forEach((h) => h(event));
        }
      });
    }

    const handlers = this.eventHandlers.get(eventType);
    if (handlers) {
      handlers.push(handler);
    }
  }

  isConnected(): boolean {
    return this.state.isConnected;
  }

  private attemptReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      logger.error(
        'Max reconnection attempts reached. Giving up on reconnection.'
      );
      return;
    }

    this.reconnectAttempts++;
    const delay = Math.min(
      this.reconnectDelay * Math.pow(2, this.reconnectAttempts - 1),
      this.maxReconnectDelay
    );

    logger.warn(
      `Attempting to reconnect to OBS (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts}) in ${delay}ms...`
    );

    this.reconnectTimeout = setTimeout(async () => {
      try {
        await this.connect();
      } catch (error) {
        logger.debug('Reconnection attempt failed:', error);
        // Will be retried on next connection close
      }
    }, delay);
  }
}
