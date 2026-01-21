import { BigNumberish } from "starknet";

export interface VaultConfigData {
  metadata: {
    vault: string;
    underlying_asset: string;
    vault_allocator: string;
    manager: string;
    root: string;
    tree_capacity: number;
    leaf_used: number;
  };
  leafs: Array<{
    decoder_and_sanitizer: string;
    target: string;
    selector: string;
    argument_addresses: string[];
    description: string;
    leaf_index: number;
    leaf_hash: string;
  }>;
  tree: Array<string[]>;
}

export interface MerkleOperation {
  manageProofs: string[];
  decoderAndSanitizer: string;
  target: string;
  selector: string;
  calldata: string[];
}

export interface BringLiquidityParams {
  amount: BigNumberish;
}

export interface ApproveParams {
  target: string;
  spender: string;
  amount: BigNumberish;
}

// ERC4626 operations
export interface DepositParams {
  target: string;
  assets: BigNumberish;
  receiver: string;
}

export interface MintParams {
  target: string;
  shares: BigNumberish;
  receiver: string;
}

export interface WithdrawParams {
  target: string;
  assets: BigNumberish;
  receiver: string;
  owner: string;
}

export interface RedeemParams {
  target: string;
  shares: BigNumberish;
  receiver: string;
  owner: string;
}

// AVNU swap
export interface Route {
  sell_token: string;
  buy_token: string;
  exchange_address: string;
  percent: BigNumberish;
  additional_swap_params: string[];
}

export interface MultiRouteSwapParamsInput {
  target: string;
  sell_token_address: string;
  sell_token_amount: BigNumberish;
  buy_token_address: string;
  buy_token_amount: BigNumberish;
  buy_token_min_amount: BigNumberish;
  integrator_fee_amount_bps: BigNumberish;
  integrator_fee_recipient: string;
  routes: Route[];
}

export interface MultiRouteSwapParams extends MultiRouteSwapParamsInput {
  beneficiary: string;
}

// Async redemption
export interface RequestRedeemParams {
  target: string;
  shares: BigNumberish;
  receiver: string;
  owner: string;
}

export interface ClaimRedeemParams {
  target: string;
  id: BigNumberish;
}

// Starkgate bridge
export interface BridgeTokenStarkgateParams {
  l1_token: string;
  l1_recipient: string;
  amount: BigNumberish;
}

// Starkgate middleware bridge
export interface BridgeTokenStarkgateMiddlewareParams {
  starkgate_token_bridge: string;
  l1_token: string;
  l1_recipient: string;
  amount: BigNumberish;
  token_to_claim: string;
}

// Note: claim_token_bridged_back is permissionless - no type needed

// Hyperlane middleware bridge
export interface BridgeTokenHyperlaneMiddlewareParams {
  source_token: string;
  destination_token: string;
  amount: BigNumberish;
  destination_domain: BigNumberish;
  recipient: string;
  strk_fee: BigNumberish;
}

// Note: claim_token for Hyperlane middleware is permissionless - no type needed

// CCTP middleware bridge
export interface BridgeTokenCctpMiddlewareParams {
  burn_token: string;
  token_to_claim: string;
  amount: BigNumberish;
  destination_domain: BigNumberish;
  mint_recipient: string;
  destination_caller: string;
  max_fee: BigNumberish;
  min_finality_threshold: BigNumberish;
}

// Note: claim_token for CCTP middleware is permissionless - no type needed

// LayerZero direct OFT
export interface BridgeLZParams {
  oft: string;
  dst_eid: BigNumberish;
  to: string; // u256 recipient address
  amount: BigNumberish;
  min_amount: BigNumberish;
  native_fee: BigNumberish; // STRK fee
  lz_token_fee?: BigNumberish; // Optional, defaults to 0
  extra_options?: string; // Optional ByteArray hex
  compose_msg?: string; // Optional ByteArray hex
  oft_cmd?: string; // Optional ByteArray hex
}

// LayerZero middleware bridge
export interface BridgeLZMiddlewareParams {
  oft: string;
  underlying_token: string;
  token_to_claim: string;
  dst_eid: BigNumberish;
  to: string; // u256 recipient address
  amount: BigNumberish;
  min_amount: BigNumberish;
  native_fee: BigNumberish; // STRK fee
  lz_token_fee?: BigNumberish; // Optional, defaults to 0
  extra_options?: string; // Optional ByteArray hex
  compose_msg?: string; // Optional ByteArray hex
  oft_cmd?: string; // Optional ByteArray hex
}

// Note: claim_token for LZ middleware is permissionless - no type needed

// Vesu V2
export interface i257 {
  abs: BigNumberish;
  is_negative: boolean;
}

export interface AmountV2 {
  denomination: "Native" | "Assets";
  value: i257;
}

export interface ModifyPositionParamsV2Input {
  target: string;
  collateral_asset: string;
  debt_asset: string;
  collateral: AmountV2;
  debt: AmountV2;
}

export interface ModifyPositionParamsV2 extends ModifyPositionParamsV2Input {
  user: string;
}

// Ekubo
export interface EkuboDepositLiquidityParams {
  target: string;
  amount0: BigNumberish;
  amount1: BigNumberish;
}

export interface EkuboWithdrawLiquidityParams {
  target: string;
  ratioWad: BigNumberish;
  minToken0: BigNumberish;
  minToken1: BigNumberish;
}

export interface EkuboCollectFeesParams {
  target: string;
}

export interface EkuboHarvestParams {
  target: string;
  rewardContract: string;
  id: BigNumberish;
  amount: BigNumberish;
  proof: string[];
  rewardToken: string;
}
