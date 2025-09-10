import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { Logger, initializeLogger } from '@forge/logger';
import { validateRelayerOnChainAumConfig } from '@forge/config';

async function bootstrap() {
  initializeLogger();
  const logger = Logger.create('RelayerOnChainAum');

  try {
    validateRelayerOnChainAumConfig(process.env);
    logger.info('Environment configuration validated successfully');
  } catch (error) {
    logger.error('Environment validation failed', error);
    process.exit(1);
  }
  await NestFactory.createApplicationContext(AppModule, {
    logger,
  });

  logger.log('RelayerOnChainAum service started');
}

bootstrap();