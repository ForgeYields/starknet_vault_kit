import { Logger } from '@forge/logger';
import { PrismaService } from '@forge/db';
import { ConfigService } from '@forge/config';
import { StarknetService } from '@forge/starknet';
import {
  SLEEP_TIME_AFTER_CLAIM_MULTIPLE_REDEEMS,
  BATCH_SIZE_FOR_CLAIM_MULTIPLE_REDEEMS,
} from './relayerAutomaticRedeem.constants';
import { Injectable } from '@nestjs/common';

@Injectable()
export class RelayerAutomaticRedeemService {
  private logger = Logger.create('RelayerAutomaticRedeem:Service');
  private isRunning = false;

  constructor(
    private prismaService: PrismaService,
    private starknetService: StarknetService,
    private configService: ConfigService
  ) {}

  async execute(): Promise<void> {
    if (this.isRunning) {
      this.logger.debug('Auto-redeem job is already running, skipping execution');
      return;
    }

    this.isRunning = true;
    try {
      await this.processAutoRedeem();
    } catch (error) {
      this.logger.error('Auto-redeem job failed:', error);
    } finally {
      this.isRunning = false;
    }
  }

  private async processAutoRedeem(): Promise<void> {
    try {
      this.logger.info('Starting auto-redeem process');

      const indexerStatus = await this.prismaService.getIndexerStatus();
      if (!indexerStatus) {
        this.logger.info('Indexer has not started yet, skipping auto-redeem');
        return;
      }

      const currentBlock = await this.starknetService.getCurrentBlock();
      const blockDifference = currentBlock - indexerStatus.lastBlock;

      if (blockDifference > 10) {
        this.logger.info('Indexer is not synced, waiting for synchronization', {
          currentBlock,
          lastIndexedBlock: indexerStatus.lastBlock,
          blocksBehind: blockDifference,
        });
        return;
      }

      this.logger.info('Indexer is synced', {
        currentBlock,
        lastIndexedBlock: indexerStatus.lastBlock,
        blockDifference,
      });

      const lastReport = await this.prismaService.fetchLastReport();

      if (!lastReport) {
        this.logger.info('No reports found, skipping auto-redeem');
        return;
      }

      this.logger.info('Found last report', {
        reportId: lastReport.id,
        epoch: lastReport.newEpoch?.toString(),
        handledEpochLen: lastReport.newHandledEpochLen?.toString(),
      });

      const pendingRedeems = await this.findPendingRedeems(lastReport);

      if (pendingRedeems.length === 0) {
        this.logger.info('No pending redeems found for auto-redeem');
        return;
      }

      this.logger.info(`Found ${pendingRedeems.length} pending redeems for processing`);

      await this.processPendingRedeemsBatches(pendingRedeems);
    } catch (error) {
      this.logger.error('Error in auto-redeem process:', error);
      throw error;
    }
  }

  private async findPendingRedeems(lastReport: any): Promise<any[]> {
    try {
      const pendingRedeems = await this.prismaService.redeemRequested.findMany({
        where: {
          redeemId: {
            notIn: await this.prismaService.redeemClaimed
              .findMany({
                select: { redeemId: true },
              })
              .then((claims) => claims.map((c) => c.redeemId)),
          },
          epoch: {
            lte: lastReport.newHandledEpochLen || 0n,
          },
        },
        orderBy: { redeemId: 'asc' },
        take: BATCH_SIZE_FOR_CLAIM_MULTIPLE_REDEEMS * 5,
      });

      this.logger.debug('Found pending redeems from database', {
        count: pendingRedeems.length,
        epochFilter: lastReport.newHandledEpochLen?.toString(),
      });

      return pendingRedeems;
    } catch (error) {
      this.logger.error('Error finding pending redeems:', error);
      return [];
    }
  }

  private async processPendingRedeemsBatches(pendingRedeems: any[]): Promise<void> {
    const batches = this.chunkArray(pendingRedeems, BATCH_SIZE_FOR_CLAIM_MULTIPLE_REDEEMS);

    this.logger.info(`Processing ${batches.length} batches of redeems`);

    for (let i = 0; i < batches.length; i++) {
      const batch = batches[i];
      try {
        this.logger.info(`Processing batch ${i + 1}/${batches.length} with ${batch.length} redeems`);

        await this.processBatch(batch);

        if (i < batches.length - 1) {
          this.logger.debug(`Sleeping for ${SLEEP_TIME_AFTER_CLAIM_MULTIPLE_REDEEMS}ms before next batch`);
          await this.sleep(SLEEP_TIME_AFTER_CLAIM_MULTIPLE_REDEEMS);
        }
      } catch (error) {
        this.logger.error(`Error processing batch ${i + 1}:`, error);
      }
    }
  }

  private async processBatch(batch: any[]): Promise<void> {
    try {
      const redeemIds = batch.map((redeem) => redeem.redeemId);
      const vaultAddress = this.configService.get('VAULT_ADDRESS') as string;
      const strategySymbol = (this.configService.get('STRATEGY_SYMBOL') as string) || 'default';

      if (!vaultAddress) {
        throw new Error('VAULT_ADDRESS configuration is required for auto-redeem');
      }

      this.logger.info('Processing redeem batch', {
        vaultAddress,
        strategySymbol,
        redeemIds: redeemIds.map((id) => id.toString()),
        batchSize: batch.length,
      });

      this.logger.info('Submitting claim redeem transaction to vault');
      const transactionHash = await this.starknetService.vault_claim_redeem(vaultAddress, redeemIds);

      this.logger.info('Transaction confirmed', {
        transactionHash,
        processedRedeemIds: redeemIds.map((id) => id.toString()),
      });

      await this.updateClaimRecords(batch, transactionHash);

      this.logger.info('Batch processed successfully', {
        transactionHash,
        processedCount: batch.length,
      });
    } catch (error) {
      this.logger.error('Error processing batch:', error);
      throw error;
    }
  }

  private async updateClaimRecords(batch: any[], transactionHash: string): Promise<void> {
    try {
      this.logger.info('Updating claim records in database', {
        batchSize: batch.length,
        transactionHash,
      });

      const currentTimestamp = Math.floor(Date.now() / 1000);

      const claimRecords = batch.map((redeem) => ({
        redeemId: redeem.redeemId,
        receiver: redeem.receiver,
        redeemRequestNominal: redeem.assets,
        assets: redeem.assets,
        epoch: redeem.epoch,
        transactionHash: transactionHash,
        timestamp: currentTimestamp,
        blockNumber: 0,
      }));

      await this.prismaService.redeemClaimed.createMany({
        data: claimRecords,
        skipDuplicates: true,
      });

      this.logger.info('Successfully updated claim records', {
        recordsCreated: claimRecords.length,
        transactionHash,
      });
    } catch (error) {
      this.logger.error('Failed to update claim records in database', error, {
        transactionHash,
        batchSize: batch.length,
      });
      this.logger.warn('Transaction was successful but database update failed - indexer will handle this');
    }
  }

  private chunkArray<T>(array: T[], chunkSize: number): T[][] {
    const chunks: T[][] = [];
    for (let i = 0; i < array.length; i += chunkSize) {
      chunks.push(array.slice(i, i + chunkSize));
    }
    return chunks;
  }

  private async sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
