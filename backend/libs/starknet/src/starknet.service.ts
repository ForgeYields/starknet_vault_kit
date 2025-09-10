import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@forge/config';
import { Provider, RpcProvider, Contract, Call, uint256, Account } from 'starknet';
import { Logger } from '@forge/logger';
import * as VAULT_ABI from './abis/vault.json';

@Injectable()
export class StarknetService implements OnModuleInit {
  private provider: Provider;
  private readonly logger = Logger.create('Starknet:Service');

  constructor(private configService: ConfigService) {}

  async onModuleInit() {
    try {
      const rpcUrl: string =
        (this.configService.get('RPC_URL') as string) || 'https://starknet-mainnet.public.blastapi.io';

      this.logger.info('Initializing StarkNet provider', { rpcUrl });
      this.provider = new RpcProvider({ nodeUrl: rpcUrl });
      this.logger.info('StarkNet provider initialized successfully');
    } catch (error) {
      this.logger.error('Failed to initialize StarkNet provider', error);
      throw error;
    }
  }

  getSigner() {
    return new Account(
      this.provider,
      this.configService.get(`RELAYER_ADDRESS`) as string,
      this.configService.get(`RELAYER_PRIVATE_KEY`) as string,
      undefined,
      '0x3'
    );
  }

  async view(address: string, abi: any, functionName: string, calldata?: any[]) {
    try {
      this.logger.debug('Making contract view call', {
        address,
        functionName,
        calldataLength: calldata?.length || 0,
      });

      const abiArray = Array.isArray(abi) ? abi : Object.values(abi);
      const contract = new Contract(abiArray, address, this.provider);

      const result = calldata ? await contract.call(functionName, calldata) : await contract.call(functionName);

      this.logger.debug('Contract view call successful', {
        address,
        functionName,
        resultType: typeof result,
      });

      return result;
    } catch (error) {
      this.logger.error('Contract view call failed', error, {
        address,
        functionName,
        calldata,
      });
      throw error;
    }
  }

  async vault_due_assets_from_id(address: string, id: number): Promise<bigint> {
    try {
      this.logger.debug('Fetching due assets from vault', { address, id });

      const due_assets = (await this.view(address, VAULT_ABI, 'due_assets_from_id', [id])) as any;

      this.logger.debug('Successfully fetched due assets', {
        address,
        id,
        dueAssets: due_assets?.toString(),
      });

      return due_assets;
    } catch (error) {
      this.logger.error('Failed to fetch due assets from vault', error, {
        address,
        id,
      });
      throw error;
    }
  }

  async vault_decimals(address: string): Promise<bigint | undefined> {
    try {
      this.logger.debug('Fetching vault decimals', { address });

      const decimals = (await this.provider.callContract({
        contractAddress: address,
        entrypoint: 'decimals',
      })) as any;

      this.logger.debug('Successfully fetched vault decimals', {
        address,
        decimals: decimals?.toString(),
      });

      return decimals;
    } catch (error) {
      this.logger.error('Failed to fetch vault decimals', error, { address });
      throw error;
    }
  }

  async vault_buffer(address: string): Promise<bigint | undefined> {
    try {
      this.logger.debug('Fetching vault buffer', { address });

      const buffer = (await this.provider.callContract({
        contractAddress: address,
        entrypoint: 'buffer',
      })) as any;

      this.logger.debug('Successfully fetched vault buffer', {
        address,
        buffer: buffer?.toString(),
      });

      return buffer;
    } catch (error) {
      this.logger.error('Failed to fetch vault buffer', error, { address });
      throw error;
    }
  }

  async vault_epoch(address: string): Promise<bigint | undefined> {
    try {
      this.logger.debug('Fetching vault epoch', { address });

      const epoch = (await this.provider.callContract({
        contractAddress: address,
        entrypoint: 'epoch',
      })) as any;

      this.logger.debug('Successfully fetched vault epoch', {
        address,
        epoch: epoch?.toString(),
      });

      return epoch;
    } catch (error) {
      this.logger.error('Failed to fetch vault epoch', error, { address });
      throw error;
    }
  }

  async vault_handled_epoch_len(address: string): Promise<bigint | undefined> {
    try {
      this.logger.debug('Fetching vault handled epoch length', { address });

      const handledEpochLen = (await this.provider.callContract({
        contractAddress: address,
        entrypoint: 'handled_epoch_len',
      })) as any;

      this.logger.debug('Successfully fetched vault handled epoch length', {
        address,
        handledEpochLen: handledEpochLen?.toString(),
      });

      return handledEpochLen;
    } catch (error) {
      this.logger.error('Failed to fetch vault handled epoch length', error, {
        address,
      });
      throw error;
    }
  }

  async vault_redeem_assets(address: string, epoch: number): Promise<bigint | undefined> {
    try {
      this.logger.debug('Fetching vault redeem assets', { address, epoch });

      const redeemAssets = (await this.provider.callContract({
        contractAddress: address,
        entrypoint: 'redeem_assets',
        calldata: [epoch],
      })) as any;

      this.logger.debug('Successfully fetched vault redeem assets', {
        address,
        epoch,
        redeemAssets: redeemAssets?.toString(),
      });

      return redeemAssets;
    } catch (error) {
      this.logger.error('Failed to fetch vault redeem assets', error, {
        address,
        epoch,
      });
      throw error;
    }
  }

  async vault_claim_redeem(address: string, redeemIds: bigint[]) {
    const functionName = 'claim_redeem';

    const calls: Array<Call> = redeemIds.map((redeemId) => {
      const redeemIdUint256 = uint256.bnToUint256(redeemId);
      return {
        contractAddress: address,
        entrypoint: functionName,
        calldata: [redeemIdUint256.low, redeemIdUint256.high],
      };
    });

    try {
      const { transaction_hash } = await this.getSigner().execute(calls);
      const txReceipt = await this.provider.waitForTransaction(transaction_hash);
      if (txReceipt.isSuccess()) {
        return transaction_hash;
      } else {
        throw new Error(
          `tx failed, hash: ${transaction_hash}, status: ${txReceipt.isSuccess() ? 'SUCCESS' : 'FAILED'}`
        );
      }
    } catch (error) {
      throw error;
    }
  }

  async getCurrentBlock(): Promise<number> {
    try {
      const block = await this.provider.getBlock('latest');
      this.logger.debug('Fetched current block', {
        blockNumber: block.block_number,
      });
      return block.block_number;
    } catch (error) {
      this.logger.error('Failed to fetch current block', error);
      throw error;
    }
  }

  async getCurrentBlockTimestamp(): Promise<number> {
    try {
      const block = await this.provider.getBlock('latest');
      this.logger.debug('Fetched current block timestamp', {
        blockNumber: block.timestamp,
      });
      return block.timestamp;
    } catch (error) {
      this.logger.error('Failed to fetch current block timestamp', error);
      throw error;
    }
  }

  async getLastReportTimestamp(vaultAddress: string): Promise<bigint> {
    try {
      const result = await this.view(vaultAddress, VAULT_ABI, 'last_report_timestamp');
      this.logger.debug('Fetched last report timestamp', {
        vaultAddress,
        timestamp: result.toString(),
      });
      return result as bigint;
    } catch (error) {
      this.logger.error('Failed to get last report timestamp', error, {
        vaultAddress,
      });
      throw error;
    }
  }

  async getReportDelay(vaultAddress: string): Promise<bigint> {
    try {
      const result = await this.view(vaultAddress, VAULT_ABI, 'report_delay');
      this.logger.debug('Fetched report delay', {
        vaultAddress,
        delay: result.toString(),
      });
      return result as bigint;
    } catch (error) {
      this.logger.error('Failed to get report delay', error, {
        vaultAddress,
      });
      throw error;
    }
  }

  async triggerAumProviderReport(aumProviderAddress: string): Promise<string> {
    try {
      this.logger.info('Triggering AUM provider report', {
        aumProviderAddress,
      });

      const calls = [
        {
          contractAddress: aumProviderAddress,
          entrypoint: 'report',
          calldata: [],
        },
      ];

      const signer = this.getSigner();
      const { transaction_hash } = await signer.execute(calls);

      this.logger.info('Report transaction submitted', {
        transactionHash: transaction_hash,
        aumProviderAddress,
      });

      const txReceipt = await this.provider.waitForTransaction(transaction_hash);

      if (txReceipt.isSuccess()) {
        this.logger.info('Report transaction successful', {
          transactionHash: transaction_hash,
        });
        return transaction_hash;
      } else {
        throw new Error(
          `Report transaction failed: ${transaction_hash}, status: ${txReceipt.isSuccess() ? 'SUCCESS' : 'FAILED'}`
        );
      }
    } catch (error) {
      this.logger.error('Failed to trigger AUM provider report', error, {
        aumProviderAddress,
      });
      throw error;
    }
  }
}
