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

export interface ClaimTokenStarkgateParams {}

// Hyperlane bridge
export interface BridgeTokenHyperlaneParams {
  source_token: string;
  destination_token: string;
  amount: BigNumberish;
  destination_domain: BigNumberish;
  recipient: string;
  strk_fee: BigNumberish;
}

export interface ClaimTokenHyperlaneParams {
  token_to_bridge: string;
  token_to_claim: string;
  destination_domain: BigNumberish;
}

// CCTP bridge
export interface BridgeTokenCctpParams {
  burn_token: string;
  token_to_claim: string;
  amount: BigNumberish;
  destination_domain: BigNumberish;
  mint_recipient: string;
  destination_caller: string;
  max_fee: BigNumberish;
  min_finality_threshold: BigNumberish;
}

export interface ClaimTokenCctpParams {
  burn_token: string;
  token_to_claim: string;
  destination_domain: BigNumberish;
}

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
  amount: BigNumberish;
  proof: string[];
  rewardToken: string;
}
