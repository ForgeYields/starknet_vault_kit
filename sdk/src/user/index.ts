import { Provider, Contract, BigNumberish, uint256 } from "starknet";
import {
  VaultConfig,
  DepositParams,
  MintParams,
  RequestRedeemParams,
  ClaimRedeemParams,
  CalldataResult,
  MultiCalldataResult,
  VaultState,
} from "../types";
import { CalldataBuilder } from "../utils/calldata";
import vaultAbi from "../abi/vault.json";

export class VaultUserSDK {
  private vaultConfig: VaultConfig;
  private provider?: Provider;
  private vaultContract?: Contract;
  private underlyingAssetAddress?: string;

  constructor(vaultConfig: VaultConfig, provider?: Provider) {
    this.vaultConfig = vaultConfig;
    this.provider = provider;
  }

  /**
   * Set the provider for reading vault state
   */
  setProvider(provider: Provider): void {
    this.provider = provider;
  }

  /**
   * Initialize vault contract for read operations
   */
  private async initContract(): Promise<void> {
    if (!this.provider) {
      throw new Error("Provider is required for contract operations");
    }

    if (!this.vaultContract) {
      this.vaultContract = new Contract(
        vaultAbi,
        this.vaultConfig.vaultAddress,
        this.provider
      );

      // Fetch underlying asset address if not cached
      if (!this.underlyingAssetAddress) {
        this.underlyingAssetAddress = await this.vaultContract.asset();
      }
    }
  }

  // === CALLDATA GENERATION METHODS ===

  /**
   * Generate calldata for deposit operation
   * If includeApprove is true, returns multiple transactions including approval
   */
  buildDepositCalldata(
    params: DepositParams
  ): CalldataResult | MultiCalldataResult {
    const depositCalldata = CalldataBuilder.buildDepositCalldata(
      this.vaultConfig.vaultAddress,
      params.assets,
      params.receiver
    );

    if (!params.includeApprove) {
      return depositCalldata;
    }

    if (!this.underlyingAssetAddress) {
      throw new Error(
        "Cannot build approval calldata: underlying asset address not loaded. Call a view method first or set includeApprove to false."
      );
    }

    const approveCalldata = CalldataBuilder.buildApproveCalldata(
      this.underlyingAssetAddress,
      this.vaultConfig.vaultAddress,
      params.assets
    );

    return {
      transactions: [approveCalldata, depositCalldata],
    };
  }

  /**
   * Generate calldata for mint operation
   * If includeApprove is true, returns multiple transactions including approval
   */
  buildMintCalldata(params: MintParams): CalldataResult | MultiCalldataResult {
    const mintCalldata = CalldataBuilder.buildMintCalldata(
      this.vaultConfig.vaultAddress,
      params.shares,
      params.receiver
    );

    if (!params.includeApprove) {
      return mintCalldata;
    }

    if (!this.underlyingAssetAddress) {
      throw new Error(
        "Cannot build approval calldata: underlying asset address not loaded. Call a view method first or set includeApprove to false."
      );
    }

    // For mint, we need to calculate required assets first
    throw new Error(
      "Cannot build mint with approval: requires async preview call. Use buildMintCalldataWithApproval() method instead."
    );
  }

  /**
   * Generate calldata for deposit operation with approval (async version)
   * Loads underlying asset address and includes approval transaction
   */
  async buildDepositCalldataWithApproval(
    params: DepositParams
  ): Promise<MultiCalldataResult> {
    if (!params.includeApprove) {
      throw new Error(
        "Use buildDepositCalldata() for deposit without approval"
      );
    }

    await this.initContract();

    const depositCalldata = CalldataBuilder.buildDepositCalldata(
      this.vaultConfig.vaultAddress,
      params.assets,
      params.receiver
    );

    const approveCalldata = CalldataBuilder.buildApproveCalldata(
      this.underlyingAssetAddress!,
      this.vaultConfig.vaultAddress,
      params.assets
    );

    return {
      transactions: [approveCalldata, depositCalldata],
    };
  }

  /**
   * Generate calldata for mint operation with approval (async version)
   * Calculates required assets and includes approval transaction
   */
  async buildMintCalldataWithApproval(
    params: MintParams
  ): Promise<MultiCalldataResult> {
    if (!params.includeApprove) {
      throw new Error("Use buildMintCalldata() for mint without approval");
    }

    await this.initContract();

    // Calculate required assets for the mint
    const requiredAssets = await this.previewMint(params.shares);

    const mintCalldata = CalldataBuilder.buildMintCalldata(
      this.vaultConfig.vaultAddress,
      params.shares,
      params.receiver
    );

    const approveCalldata = CalldataBuilder.buildApproveCalldata(
      this.underlyingAssetAddress!,
      this.vaultConfig.vaultAddress,
      requiredAssets
    );

    return {
      transactions: [approveCalldata, mintCalldata],
    };
  }

  /**
   * Generate calldata for request redeem operation
   */
  buildRequestRedeemCalldata(params: RequestRedeemParams): CalldataResult {
    return CalldataBuilder.buildRequestRedeemCalldata(
      this.vaultConfig.vaultAddress,
      params.shares,
      params.receiver,
      params.owner
    );
  }

  /**
   * Generate calldata for claim redeem operation
   */
  buildClaimRedeemCalldata(params: ClaimRedeemParams): CalldataResult {
    return CalldataBuilder.buildClaimRedeemCalldata(
      this.vaultConfig.vaultAddress,
      params.id
    );
  }

  // === VIEW METHODS ===

  /**
   * Get current vault state
   */
  async getVaultState(): Promise<VaultState> {
    await this.initContract();

    const [epoch, handledEpochLen, buffer, aum, totalSupply, totalAssets] =
      await Promise.all([
        this.vaultContract!.epoch(),
        this.vaultContract!.handled_epoch_len(),
        this.vaultContract!.buffer(),
        this.vaultContract!.aum(),
        this.vaultContract!.total_supply(),
        this.vaultContract!.total_assets(),
      ]);

    return {
      epoch: BigInt(uint256.uint256ToBN(epoch).toString()),
      handledEpochLen: BigInt(uint256.uint256ToBN(handledEpochLen).toString()),
      buffer: BigInt(uint256.uint256ToBN(buffer).toString()),
      aum: BigInt(uint256.uint256ToBN(aum).toString()),
      totalSupply: BigInt(uint256.uint256ToBN(totalSupply).toString()),
      totalAssets: BigInt(uint256.uint256ToBN(totalAssets).toString()),
    };
  }

  /**
   * Get user's share balance
   */
  async getUserShareBalance(userAddress: string): Promise<bigint> {
    await this.initContract();
    const balance = await this.vaultContract!.balance_of(userAddress);
    return BigInt(uint256.uint256ToBN(balance).toString());
  }

  /**
   * Preview how many shares will be received for a deposit
   */
  async previewDeposit(assets: BigNumberish): Promise<bigint> {
    await this.initContract();
    const shares = await this.vaultContract!.preview_deposit(
      uint256.bnToUint256(assets.toString())
    );
    return BigInt(uint256.uint256ToBN(shares).toString());
  }

  /**
   * Preview how many assets are needed to mint shares
   */
  async previewMint(shares: BigNumberish): Promise<bigint> {
    await this.initContract();
    const assets = await this.vaultContract!.preview_mint(
      uint256.bnToUint256(shares.toString())
    );
    return BigInt(uint256.uint256ToBN(assets).toString());
  }

  /**
   * Preview how many assets will be received for redeeming shares
   */
  async previewRedeem(shares: BigNumberish): Promise<bigint> {
    await this.initContract();
    const assets = await this.vaultContract!.preview_redeem(
      uint256.bnToUint256(shares.toString())
    );
    return BigInt(uint256.uint256ToBN(assets).toString());
  }

  /**
   * Get expected assets for a redemption NFT ID
   */
  async getDueAssetsFromId(id: BigNumberish): Promise<bigint> {
    await this.initContract();
    const assets = await this.vaultContract!.due_assets_from_id(
      uint256.bnToUint256(id.toString())
    );
    return BigInt(uint256.uint256ToBN(assets).toString());
  }

  /**
   * Convert assets to shares
   */
  async convertToShares(assets: BigNumberish): Promise<bigint> {
    await this.initContract();
    const shares = await this.vaultContract!.convert_to_shares(
      uint256.bnToUint256(assets.toString())
    );
    return BigInt(uint256.uint256ToBN(shares).toString());
  }

  /**
   * Convert shares to assets
   */
  async convertToAssets(shares: BigNumberish): Promise<bigint> {
    await this.initContract();
    const assets = await this.vaultContract!.convert_to_assets(
      uint256.bnToUint256(shares.toString())
    );
    return BigInt(uint256.uint256ToBN(assets).toString());
  }

  /**
   * Get the underlying asset contract address
   */
  async getUnderlyingAssetAddress(): Promise<string> {
    await this.initContract();
    return this.underlyingAssetAddress!;
  }

  /**
   * Get the redeem request NFT contract address
   */
  async getRedeemRequestAddress(): Promise<string> {
    await this.initContract();
    const address = await this.vaultContract!.redeem_request();
    return address.toString();
  }
}
