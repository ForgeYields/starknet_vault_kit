import * as winston from 'winston';
import * as DailyRotateFile from 'winston-daily-rotate-file';

export enum LogLevel {
  ERROR = 'error',
  WARN = 'warn',
  INFO = 'info',
  DEBUG = 'debug',
}

export interface LoggerConfig {
  level?: LogLevel;
  service?: string;
  enableConsole?: boolean;
  enableFile?: boolean;
  logDir?: string;
  maxFiles?: string;
  maxSize?: string;
  format?: 'json' | 'simple';
}

export class Logger {
  private winston: winston.Logger;
  private context: string;
  private static instances: Map<string, Logger> = new Map();

  private constructor(context: string, config: LoggerConfig = {}) {
    this.context = context;
    this.winston = this.createWinstonLogger(config);
  }

  private createWinstonLogger(config: LoggerConfig): winston.Logger {
    const {
      level = LogLevel.INFO,
      service = 'starknet-vault-kit',
      enableConsole = true,
      enableFile = true,
      logDir = 'logs',
      maxFiles = '14d',
      maxSize = '20m',
      format = 'json',
    } = config;

    const logFormat = format === 'json' 
      ? winston.format.combine(
          winston.format.timestamp(),
          winston.format.errors({ stack: true }),
          winston.format.json(),
          winston.format.printf(({ timestamp, level, message, service, context, ...meta }) => {
            const baseLog = {
              timestamp,
              level,
              service,
              context,
              message,
            };
            return JSON.stringify(Object.keys(meta).length ? { ...baseLog, ...meta } : baseLog);
          })
        )
      : winston.format.combine(
          winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
          winston.format.errors({ stack: true }),
          winston.format.printf(({ timestamp, level, message, context, service, ...meta }) => {
            const metaStr = Object.keys(meta).length ? ` ${JSON.stringify(meta)}` : '';
            return `${timestamp} [${level.toUpperCase()}] [${service}:${context}] ${message}${metaStr}`;
          })
        );

    const transports: winston.transport[] = [];

    if (enableConsole) {
      transports.push(
        new winston.transports.Console({
          level,
          format: winston.format.combine(
            winston.format.colorize({ all: false, level: true }),
            winston.format.timestamp({ format: 'HH:mm:ss' }),
            winston.format.printf(({ timestamp, level, message, context, ...meta }) => {
              const contextStr = context ? `[${context}]` : '';
              const metaStr = Object.keys(meta).length > 1 ? ` ${JSON.stringify(
                Object.fromEntries(
                  Object.entries(meta).filter(([key]) => key !== 'service')
                ), null, 2
              )}` : '';
              return `${timestamp} ${level} ${contextStr} ${message}${metaStr}`;
            })
          ),
        })
      );
    }

    if (enableFile) {
      transports.push(
        new DailyRotateFile({
          dirname: logDir,
          filename: `${service}-%DATE%.log`,
          datePattern: 'YYYY-MM-DD',
          maxFiles,
          maxSize,
          level,
          format: logFormat,
        }),
        new DailyRotateFile({
          dirname: logDir,
          filename: `${service}-error-%DATE%.log`,
          datePattern: 'YYYY-MM-DD',
          level: 'error',
          maxFiles,
          maxSize,
          format: logFormat,
        })
      );
    }

    return winston.createLogger({
      level,
      defaultMeta: { service, context: this.context },
      transports,
      exitOnError: false,
    });
  }

  info(message: string, meta?: any): void {
    this.winston.info(message, meta);
  }

  log(message: string, meta?: any): void {
    this.winston.info(message, meta);
  }

  error(message: string, error?: Error | any, meta?: any): void {
    const errorMeta = error instanceof Error 
      ? { error: error.message, stack: error.stack, ...meta }
      : { error, ...meta };
    
    this.winston.error(message, errorMeta);
  }

  warn(message: string, meta?: any): void {
    this.winston.warn(message, meta);
  }

  debug(message: string, meta?: any): void {
    this.winston.debug(message, meta);
  }

  child(childContext: string): Logger {
    const fullContext = `${this.context}:${childContext}`;
    return Logger.create(fullContext);
  }

  static create(context: string = 'Application', config?: LoggerConfig): Logger {
    if (!Logger.instances.has(context)) {
      Logger.instances.set(context, new Logger(context, config));
    }
    return Logger.instances.get(context)!;
  }

  static configure(globalConfig: LoggerConfig): void {
    Logger.instances.clear();
    Logger.defaultConfig = globalConfig;
  }

  private static defaultConfig: LoggerConfig = {};

  static getDefaultConfig(): LoggerConfig {
    return Logger.defaultConfig;
  }
}