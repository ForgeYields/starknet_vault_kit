import { NestFactory } from '@nestjs/core';
import { validateIndexerConfig } from '@forge/config';
import { Logger, initializeLogger } from '@forge/logger';
import { IndexerModule } from './indexer.module';
import { IndexerService } from './indexer.service';

async function bootstrap() {
  initializeLogger();
  const logger = Logger.create('Indexer:Main');

  try {
    validateIndexerConfig(process.env);
    logger.info('Environment configuration validated successfully');

    const app = await NestFactory.create(IndexerModule);
    const indexerService = app.get(IndexerService);

    logger.info('Starting StarkNet Vault Kit Indexer');

    await indexerService.run();
  } catch (error) {
    logger.error('Indexer failed', error);
    process.exit(1);
  }
}

bootstrap().catch((error) => {
  const logger = Logger.create('Indexer:Main');
  logger.error('Bootstrap failed', error);
  process.exit(1);
});
