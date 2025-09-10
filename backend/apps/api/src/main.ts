import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { validateApiConfig } from '@forge/config';
import { Logger, initializeLogger } from '@forge/logger';
import { AppModule } from './app.module';

async function bootstrap() {
  initializeLogger();
  const logger = Logger.create('API:Main');

  try {
    validateApiConfig(process.env);
    logger.info('Environment configuration validated successfully');

    const app = await NestFactory.create(AppModule);

    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      })
    );
    logger.info('Global validation pipes configured');

    app.enableCors();
    logger.info('CORS enabled');
    const config = new DocumentBuilder()
      .setTitle('StarkNet Vault Kit API')
      .setDescription('API for StarkNet Vault Kit indexer and services')
      .setVersion('1.0')
      .build();

    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('api', app, document);
    logger.info('Swagger documentation configured at /api');

    const port = process.env.PORT || 3000;
    await app.listen(port);

    logger.info(`API server started on port ${port}`, {
      environment: process.env.NODE_ENV || 'development',
      docs: `/api`,
    });
  } catch (error) {
    logger.error('Failed to start API server', error);
    process.exit(1);
  }
}

bootstrap();
