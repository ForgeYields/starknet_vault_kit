import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '@forge/db';
import { StarknetService } from '@forge/starknet';
import Decimal from 'decimal.js';
import { ConfigService } from '@forge/config';
import { Logger } from '@forge/logger';
import { validateAndParseAddress } from 'starknet';
// Types moved from @forge/core
export interface Strategy {
  vault: string;
  startBlockIndexing: number;
}

export interface PendingRedeem {
  epoch: number;
  sharesBurn: string;
  nominal: string;
  assets: string;
  redeemId: string;
  timestamp: number;
  transactionHash: string;
}

export interface StrategyAnalytics {
  sharePrice: string;
  totalSupply: string;
  totalAssets: string;
  epoch: string;
  timestamp: number;
  managementFeeShares: string;
  performanceFeeShares: string;
  apy1Report?: string;
  apy2Reports?: string;
  apy3Reports?: string;
  redeemDelaySeconds?: number;
}

export interface RedeemRequiredAssets {
  epoch: number;
  is_current_epoch: boolean;
  redeem_assets_required: string;
  cumulated_liquidity_required: string;
}

@Injectable()
export class AppService implements OnModuleInit {
  strategyDecimals: number;
  private readonly logger = Logger.create('API:Service');

  constructor(
    private readonly prismaService: PrismaService,
    private readonly starknetService: StarknetService,
    private readonly configService: ConfigService
  ) {}

  async onModuleInit() {
    try {
      const vaultAddress = this.configService.get('VAULT_ADDRESS') as string;
      this.logger.info('Initializing AppService', { vaultAddress });
      this.strategyDecimals = Number(await this.starknetService.vault_decimals(vaultAddress));
      this.logger.info('AppService initialized successfully', {
        strategyDecimals: this.strategyDecimals,
        vaultAddress,
      });
    } catch (error) {
      this.logger.error('Failed to initialize AppService', error);
      throw error;
    }
  }

  getApiInfo() {
    return {
      name: 'StarkNet Vault Kit API',
      version: '1.0.0',
      description: 'Backend API for StarkNet Vault Kit',
      endpoints: {
        health: '/health',
        pendingRedeems: '/pending-redeems/:address',
        lastReport: '/reports/last',
        redeemById: '/redeems/:id',
        strategyAnalytics: '/strategy-analytics',
        redeemRequiredAssets: '/redeem-required-assets',
      },
      documentation: '/api',
    };
  }

  public async getPendingRedeems(address: string, limit?: number, offset?: number): Promise<PendingRedeem[]> {
    try {
      const addressToUse = validateAndParseAddress(address);
      this.logger.info('Fetching pending redeems', {
        address: addressToUse,
        limit,
        offset,
      });

      const pendingRedeems: PendingRedeem[] = [];
      const vaultAddress = this.configService.get('VAULT_ADDRESS') as string;

      const lastRedeemRequestedIdForAddress =
        await this.prismaService.fetchLastRedeemRequestedIdForAddress(addressToUse);

      if (lastRedeemRequestedIdForAddress === undefined) {
        return [];
      }

      const pendingRedeemsForStrategy = await this.prismaService.fetchPendingRedeemsForAddress(
        addressToUse,
        -1, // Start from the beginning
        Number(lastRedeemRequestedIdForAddress), // Up to the last requested ID
        limit,
        offset
      );

      this.logger.debug('Found pending redeems from database', {
        count: pendingRedeemsForStrategy.length,
      });

      const pendingRedeemPromises = pendingRedeemsForStrategy.map(async (redeem) => {
        try {
          const dueAssets = await this.starknetService.vault_due_assets_from_id(vaultAddress, Number(redeem.redeemId));

          return {
            epoch: Number(redeem.epoch),
            sharesBurn: this.formatBigIntToDecimal(redeem.shares),
            nominal: this.formatBigIntToDecimal(redeem.assets),
            assets: this.formatBigIntToDecimal(dueAssets),
            redeemId: redeem.redeemId.toString(),
            timestamp: redeem.timestamp,
            transactionHash: redeem.transactionHash,
          };
        } catch (error) {
          this.logger.error('Failed to process pending redeem', error, {
            redeemId: redeem.redeemId.toString(),
          });
          throw error;
        }
      });

      const resolvedPendingRedeems = await Promise.all(pendingRedeemPromises);
      resolvedPendingRedeems.sort((a, b) => Number(b.redeemId) - Number(a.redeemId));
      pendingRedeems.push(...resolvedPendingRedeems);

      this.logger.info('Successfully processed pending redeems', {
        address: addressToUse,
        count: resolvedPendingRedeems.length,
      });

      return pendingRedeems;
    } catch (error) {
      this.logger.error('Failed to get pending redeems', error, { address });
      throw error;
    }
  }

  public async getLastReport() {
    try {
      this.logger.debug('Fetching last report');

      const lastReport = await this.prismaService.fetchLastReport();
      if (!lastReport) {
        this.logger.info('No reports found in database');
        return null;
      }

      const result = {
        id: lastReport.id,
        blockNumber: lastReport.blockNumber,
        timestamp: lastReport.timestamp,
        transactionHash: lastReport.transactionHash,
        newEpoch: lastReport.newEpoch.toString(),
        newHandledEpochLen: lastReport.newHandledEpochLen.toString(),
        totalSupply: this.formatBigIntToDecimal(lastReport.totalSupply),
        totalAssets: this.formatBigIntToDecimal(lastReport.totalAssets),
        managementFeeShares: this.formatBigIntToDecimal(lastReport.managementFeeShares),
        performanceFeeShares: this.formatBigIntToDecimal(lastReport.performanceFeeShares),
      };

      this.logger.info('Successfully fetched last report', {
        reportId: result.id,
        blockNumber: result.blockNumber,
        epoch: result.newEpoch,
      });

      return result;
    } catch (error) {
      this.logger.error('Failed to get last report', error);
      throw error;
    }
  }

  public async getRedeemById(redeemId: string) {
    try {
      this.logger.info('Fetching redeem by ID', { redeemId });

      const redeemRequested = await this.prismaService.redeemRequested.findUnique({
        where: { redeemId: BigInt(redeemId) },
      });

      if (!redeemRequested) {
        this.logger.info('Redeem request not found', { redeemId });
        return null;
      }

      const redeemClaimed = await this.prismaService.redeemClaimed.findUnique({
        where: { redeemId: BigInt(redeemId) },
      });

      let currentDueAssets: bigint | null = null;
      if (!redeemClaimed) {
        try {
          const vaultAddress = this.configService.get('VAULT_ADDRESS') as string;
          currentDueAssets = await this.starknetService.vault_due_assets_from_id(vaultAddress, Number(redeemId));
          this.logger.debug('Fetched current due assets from contract', {
            redeemId,
            dueAssets: currentDueAssets?.toString(),
          });
        } catch (error) {
          this.logger.warn('Failed to fetch due assets for redeem ID', {
            redeemId,
            error: error.message,
          });
        }
      }

      const result = {
        redeemId: redeemRequested.redeemId.toString(),
        owner: redeemRequested.owner,
        receiver: redeemRequested.receiver,
        epoch: redeemRequested.epoch.toString(),
        sharesBurn: this.formatBigIntToDecimal(redeemRequested.shares),
        nominal: this.formatBigIntToDecimal(redeemRequested.assets),
        assets: currentDueAssets ? this.formatBigIntToDecimal(currentDueAssets) : null,
        requestTimestamp: redeemRequested.timestamp,
        requestTransactionHash: redeemRequested.transactionHash,
        claimedTimestamp: redeemClaimed?.timestamp,
        claimedTransactionHash: redeemClaimed?.transactionHash,
        claimedAssets: redeemClaimed ? this.formatBigIntToDecimal(redeemClaimed.assets) : null,
      };

      this.logger.info('Successfully fetched redeem details', {
        redeemId,
        isClaimed: !!redeemClaimed,
        owner: result.owner,
      });

      return result;
    } catch (error) {
      this.logger.error('Failed to get redeem by ID', error, { redeemId });
      throw error;
    }
  }

  public async getStrategyAnalytics(limit: number = 10, offset?: number): Promise<StrategyAnalytics[]> {
    try {
      this.logger.info('Fetching strategy analytics', { limit, offset });

      const reports = await this.prismaService.fetchLastReports(limit, offset);

      if (!reports || reports.length === 0) {
        this.logger.info('No reports found for analytics');
        return [];
      }

      this.logger.debug('Found reports for analytics', { count: reports.length });

      const calculateAPY = (
        currentSharePrice: Decimal,
        previousSharePrice: Decimal,
        currentTimestamp: number,
        previousTimestamp: number
      ): string => {
        const priceRatio = currentSharePrice.div(previousSharePrice);
        const growth = priceRatio.sub(1);
        const timeDiffSeconds = currentTimestamp - previousTimestamp;
        const timeDiffYears = timeDiffSeconds / (365.25 * 24 * 60 * 60);
        const annualizedGrowth = growth.div(timeDiffYears);
        return annualizedGrowth.mul(100).toString();
      };

      const analytics = reports.map((report, index) => {
        const sharePrice =
          report.totalSupply > 0n
            ? new Decimal(report.totalAssets.toString()).div(new Decimal(report.totalSupply.toString()))
            : new Decimal(1);

        let apy1Report: string | undefined;
        let apy2Reports: string | undefined;
        let apy3Reports: string | undefined;

        if (index + 1 < reports.length) {
          const prevReport = reports[index + 1];
          const prevSharePrice =
            prevReport.totalSupply > 0n
              ? new Decimal(prevReport.totalAssets.toString()).div(new Decimal(prevReport.totalSupply.toString()))
              : new Decimal(1);
          apy1Report = calculateAPY(sharePrice, prevSharePrice, report.timestamp, prevReport.timestamp);
        }

        if (index + 2 < reports.length) {
          const prevReport = reports[index + 2];
          const prevSharePrice =
            prevReport.totalSupply > 0n
              ? new Decimal(prevReport.totalAssets.toString()).div(new Decimal(prevReport.totalSupply.toString()))
              : new Decimal(1);
          apy2Reports = calculateAPY(sharePrice, prevSharePrice, report.timestamp, prevReport.timestamp);
        }

        if (index + 3 < reports.length) {
          const prevReport = reports[index + 3];
          const prevSharePrice =
            prevReport.totalSupply > 0n
              ? new Decimal(prevReport.totalAssets.toString()).div(new Decimal(prevReport.totalSupply.toString()))
              : new Decimal(1);
          apy3Reports = calculateAPY(sharePrice, prevSharePrice, report.timestamp, prevReport.timestamp);
        }

        let redeemDelaySeconds: number | undefined;

        if (index === 0) {
          redeemDelaySeconds = undefined;
        } else {
          const currentEpoch = Number(report.newEpoch);
          const handlingReport = reports.find((r) => Number(r.newHandledEpochLen) >= currentEpoch);

          if (handlingReport) {
            redeemDelaySeconds = handlingReport.timestamp - report.timestamp;
          } else {
            redeemDelaySeconds = undefined;
          }
        }

        return {
          sharePrice: sharePrice.toString(),
          totalSupply: this.formatBigIntToDecimal(report.totalSupply),
          totalAssets: this.formatBigIntToDecimal(report.totalAssets),
          epoch: report.newEpoch.toString(),
          timestamp: report.timestamp,
          managementFeeShares: this.formatBigIntToDecimal(report.managementFeeShares),
          performanceFeeShares: this.formatBigIntToDecimal(report.performanceFeeShares),
          apy1Report,
          apy2Reports,
          apy3Reports,
          redeemDelaySeconds,
        };
      });

      this.logger.info('Successfully processed strategy analytics', {
        count: analytics.length,
      });

      return analytics;
    } catch (error) {
      this.logger.error('Failed to get strategy analytics', error);
      throw error;
    }
  }

  public async getRedeemRequiredAssets(): Promise<RedeemRequiredAssets[]> {
    try {
      this.logger.info('Fetching redeem required assets');

      const vaultAddress = this.configService.get('VAULT_ADDRESS') as string;

      let [buffer, epoch, handledEpochLen] = await Promise.all([
        this.starknetService.vault_buffer(vaultAddress),
        this.starknetService.vault_epoch(vaultAddress),
        this.starknetService.vault_handled_epoch_len(vaultAddress),
      ]);

      this.logger.debug('Fetched vault state', {
        buffer: buffer?.toString(),
        epoch: epoch?.toString(),
        handledEpochLen: handledEpochLen?.toString(),
      });

      let redeemRequiredAssets: RedeemRequiredAssets[] = [];

      for (let index = Number(handledEpochLen); index <= Number(epoch); index++) {
        const redeemAssets = await this.starknetService.vault_redeem_assets(vaultAddress, index);

        let cumulated_liquidity_required = redeemAssets;

        if (buffer >= redeemAssets) {
          buffer -= redeemAssets;
          cumulated_liquidity_required = 0n;
        } else {
          buffer = 0n;
          cumulated_liquidity_required = redeemAssets - buffer;
        }

        redeemRequiredAssets.push({
          epoch: index,
          is_current_epoch: index === Number(epoch),
          redeem_assets_required: this.formatBigIntToDecimal(redeemAssets),
          cumulated_liquidity_required: this.formatBigIntToDecimal(cumulated_liquidity_required),
        });
      }

      this.logger.info('Successfully calculated redeem required assets', {
        epochsProcessed: redeemRequiredAssets.length,
      });

      return redeemRequiredAssets;
    } catch (error) {
      this.logger.error('Failed to get redeem required assets', error);
      throw error;
    }
  }

  formatBigIntToDecimal = (value: bigint): string => {
    return new Decimal(value.toString()).div(new Decimal(10).pow(this.strategyDecimals)).toFixed();
  };

  async getIndexerStatus() {
    const status = await this.prismaService.getIndexerStatus();
    if (!status) {
      return {
        lastBlock: 0,
        updatedAt: null,
        synced: false,
        message: 'Indexer has not started yet',
      };
    }

    return {
      lastBlock: status.lastBlock,
      updatedAt: status.updatedAt,
      synced: true,
      message: 'Indexer is running',
    };
  }
}
