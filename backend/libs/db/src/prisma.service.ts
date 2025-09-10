import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient, RedeemRequested, Report, RedeemClaimed, IndexerStatus } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }

  async fetchLastRedeemRequested(): Promise<any | undefined> {
    try {
      const latest = await this.redeemRequested.findFirst({
        orderBy: { blockNumber: 'desc' },
      });
      return latest as RedeemRequested | undefined;
    } catch (error) {
      // Table doesn't exist yet, return undefined
      return undefined;
    }
  }

  async fetchLastReport(): Promise<Report | undefined> {
    try {
      const latest = await this.report.findFirst({
        orderBy: { blockNumber: 'desc' },
      });
      return latest as Report | undefined;
    } catch (error) {
      // Table doesn't exist yet, return undefined
      return undefined;
    }
  }

  async fetchLastReports(limit: number, offset?: number): Promise<Report[]> {
    try {
      const reports = await this.report.findMany({
        orderBy: { blockNumber: 'desc' },
        take: limit,
        ...(offset && { skip: offset }),
      });
      return reports as Report[];
    } catch (error) {
      // Table doesn't exist yet, return empty array
      return [];
    }
  }

  async fetchLastRedeemClaimed(): Promise<RedeemClaimed | undefined> {
    try {
      const latest = await this.redeemClaimed.findFirst({
        orderBy: { blockNumber: 'desc' },
      });
      return latest as RedeemClaimed | undefined;
    } catch (error) {
      // Table doesn't exist yet, return undefined
      return undefined;
    }
  }

  async fetchLastRedeemRequestedIdForAddress(receiver: string): Promise<number | undefined> {
    try {
      const latest = await this.redeemRequested.findFirst({
        where: { receiver },
        orderBy: { redeemId: 'desc' },
        select: { redeemId: true },
      });
      return latest?.redeemId !== undefined ? Number(latest.redeemId) : undefined;
    } catch (error) {
      // Table doesn't exist yet, return undefined
      return undefined;
    }
  }

  async fetchLastRedeemClaimedIdForAddress(receiver: string): Promise<number | undefined> {
    try {
      const latest = await this.redeemClaimed.findFirst({
        where: { receiver },
        orderBy: { redeemId: 'desc' },
        select: { redeemId: true },
      });
      return latest?.redeemId !== undefined ? Number(latest.redeemId) : undefined;
    } catch (error) {
      // Table doesn't exist yet, return undefined
      return undefined;
    }
  }

  public async fetchPendingRedeemsForAddress(
    receiver: string,
    minRedeemId: number,
    maxRedeemId: number,
    limit?: number,
    offset?: number
  ): Promise<RedeemRequested[]> {
    try {
      // Get all claimed redeem IDs for this address in the range
      const claimedRedeemIds = await this.redeemClaimed.findMany({
        where: {
          receiver,
          redeemId: {
            gt: minRedeemId,
            lte: maxRedeemId,
          },
        },
        select: { redeemId: true },
      });

      const claimedIds = claimedRedeemIds.map((r) => r.redeemId);

      // Find all requested redeems in the range that are NOT in the claimed list
      return this.redeemRequested.findMany({
        where: {
          receiver,
          redeemId: {
            gt: minRedeemId,
            lte: maxRedeemId,
            notIn: claimedIds,
          },
        },
        orderBy: {
          redeemId: 'desc',
        },
        ...(limit && { take: limit }),
        ...(offset && { skip: offset }),
      });
    } catch (error) {
      // Tables don't exist yet, return empty array
      return [];
    }
  }

  async updateIndexerStatus(lastBlock: number): Promise<IndexerStatus> {
    return this.indexerStatus.upsert({
      where: { id: 1 },
      update: { lastBlock },
      create: { id: 1, lastBlock },
    });
  }

  async getIndexerStatus(): Promise<IndexerStatus | null> {
    try {
      return await this.indexerStatus.findUnique({
        where: { id: 1 },
      });
    } catch (error) {
      // Table doesn't exist yet, return null
      return null;
    }
  }
}
