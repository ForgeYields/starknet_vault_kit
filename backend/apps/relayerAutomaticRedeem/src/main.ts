import { NestFactory } from "@nestjs/core";
import { validateRelayerAutomaticRedeemConfig } from "@forge/config";
import { Logger, initializeLogger } from "@forge/logger";
import { RelayerAutomaticRedeemModule } from "./relayerAutomaticRedeem.module";
import { RelayerAutomaticRedeemService } from "./relayerAutomaticRedeem.service";

async function bootstrap() {
  initializeLogger();
  const logger = Logger.create("RelayerAutomaticRedeem:Main");

  try {
    validateRelayerAutomaticRedeemConfig(process.env);
    logger.info('Environment configuration validated successfully');

    const app = await NestFactory.create(RelayerAutomaticRedeemModule);
    await app.init();
    const relayerAutomaticRedeemService = app.get(RelayerAutomaticRedeemService);

    logger.info("Starting StarkNet Vault Kit Relayer");
    
    let shouldShutdown = false;
    const gracefulShutdown = async (signal: string) => {
      logger.info(`Received ${signal}, shutting down gracefully`);
      shouldShutdown = true;
      await app.close();
      process.exit(0);
    };

    process.on("SIGINT", () => gracefulShutdown("SIGINT"));
    process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
    
    while (!shouldShutdown) {
      try {
        await relayerAutomaticRedeemService.execute();
        
        logger.debug("Waiting 5 minutes before next execution");
        await new Promise(resolve => setTimeout(resolve, 5 * 60 * 1000));
      } catch (error) {
        logger.error("Relayer execution failed:", error);
        
        logger.warn("Waiting 1 minute before retry after error");
        await new Promise(resolve => setTimeout(resolve, 1 * 60 * 1000));
      }
    }

    logger.info("Relayer started successfully");
  } catch (error) {
    logger.error("Bootstrap failed", error);
    process.exit(1);
  }
}

bootstrap();
