import { LogLevel, LoggerConfig } from './logger';

export const getLoggerConfig = (): LoggerConfig => {
  const isDevelopment = process.env.NODE_ENV === 'development';
  const logLevel = (process.env.LOG_LEVEL as LogLevel) || (isDevelopment ? LogLevel.DEBUG : LogLevel.INFO);
  
  return {
    level: logLevel,
    service: 'starknet-vault-kit',
    enableConsole: true,
    enableFile: process.env.ENABLE_FILE_LOGGING === 'true' || !isDevelopment,
    logDir: process.env.LOG_DIR || 'logs',
    maxFiles: '14d',
    maxSize: '20m',
    format: isDevelopment ? 'simple' : 'json',
  };
};

export const initializeLogger = (): void => {
  const { Logger } = require('./logger');
  Logger.configure(getLoggerConfig());
};