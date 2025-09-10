import { BigNumberish, Call } from "starknet";

export interface VaultConfig {
  vaultAddress: string;
}

export interface DepositParams {
  assets: BigNumberish;
  receiver: string;
  includeApprove?: boolean; // Include approval transaction for underlying asset
}

export interface MintParams {
  shares: BigNumberish;
  receiver: string;
  includeApprove?: boolean; // Include approval transaction for underlying asset
}

export interface RequestRedeemParams {
  shares: BigNumberish;
  receiver: string;
  owner: string;
}

export interface ClaimRedeemParams {
  id: BigNumberish;
}

export interface VaultState {
  epoch: bigint;
  handledEpochLen: bigint;
  buffer: bigint;
  aum: bigint;
  totalSupply: bigint;
  totalAssets: bigint;
}

export interface FeesConfig {
  feesRecipient: string;
  redeemFees: bigint;
  managementFees: bigint;
  performanceFees: bigint;
}

export interface ReportParams {
  newAum: BigNumberish;
}

export interface BringLiquidityParams {
  amount: BigNumberish;
}

export interface CalldataResult {
  contractAddress: string;
  entrypoint: string;
  calldata: string[];
}

export interface MultiCalldataResult {
  transactions: CalldataResult[];
}

export { Call };
