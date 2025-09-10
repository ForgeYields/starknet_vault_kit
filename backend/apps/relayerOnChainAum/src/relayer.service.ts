import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@forge/config';
import { StarknetService } from '@forge/starknet';
import { Logger } from '@forge/logger';

@Injectable()
export class RelayerService implements OnModuleInit {
  private readonly logger = Logger.create('RelayerOnChainAum:Service');
  private vaultAddress: string;
  private onChainAumProvider: string;

  private isRunning = false;

  constructor(
    private configService: ConfigService,
    private starknetService: StarknetService
  ) {}

  async onModuleInit() {
    this.vaultAddress = this.configService.get('VAULT_ADDRESS') as string;
    this.onChainAumProvider = this.configService.get('ON_CHAIN_AUM_PROVIDER') as string;

    this.logger.info('RelayerOnChainAum service initialized', {
      vaultAddress: this.vaultAddress,
      onChainAumProvider: this.onChainAumProvider,
    });

    // Start the continuous monitoring loop
    this.startMonitoring();
  }

  private async startMonitoring() {
    if (this.isRunning) return;
    this.isRunning = true;

    this.logger.info('Starting AUM reporting monitoring loop');

    while (this.isRunning) {
      try {
        const nextReportTime = await this.getNextReportTime();
        const now = await this.starknetService.getCurrentBlockTimestamp();

        if (nextReportTime <= now) {
          this.logger.info('Report is ready, triggering AUM provider report');
          await this.starknetService.triggerAumProviderReport(this.onChainAumProvider);

          await this.sleep(60 * 1000);
        } else {
          const sleepTime = (nextReportTime - now) * 1000; // Convert to milliseconds
          const sleepMinutes = Math.round(sleepTime / (60 * 1000));

          this.logger.info(`Next report ready in ${sleepMinutes} minutes, sleeping until then`, {
            nextReportTime,
            currentTime: now,
            sleepTimeMs: sleepTime,
          });

          await this.sleep(sleepTime);
        }
      } catch (error) {
        this.logger.error('Error in monitoring loop, retrying in 5 minutes', error);
        await this.sleep(5 * 60 * 1000); // Sleep 5 minutes on error
      }
    }
  }

  private async getNextReportTime(): Promise<number> {
    const [lastReportTimestamp, reportDelay] = await Promise.all([
      this.starknetService.getLastReportTimestamp(this.vaultAddress),
      this.starknetService.getReportDelay(this.vaultAddress),
    ]);

    const nextReportTime = Number(lastReportTimestamp) + Number(reportDelay);

    this.logger.debug('Calculated next report time', {
      lastReportTimestamp: lastReportTimestamp.toString(),
      reportDelay: reportDelay.toString(),
      nextReportTime,
    });

    return nextReportTime;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  public stop() {
    this.logger.info('Stopping AUM reporting monitoring');
    this.isRunning = false;
  }
}
