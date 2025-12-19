import { uint256, selector } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  EkuboDepositLiquidityParams,
  EkuboWithdrawLiquidityParams,
  EkuboCollectFeesParams,
  EkuboHarvestParams,
} from "../types";

export function ekuboDepositLiquidity(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: EkuboDepositLiquidityParams
): MerkleOperation {
  const depositLiquiditySelector = BigInt(
    selector.getSelectorFromName("deposit_liquidity")
  ).toString();
  const depositLiquidityLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === depositLiquiditySelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!depositLiquidityLeaf) {
    throw new Error(
      "Ekubo deposit liquidity operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, depositLiquidityLeaf.leaf_hash);

  const amount0Uint256 = uint256.bnToUint256(params.amount0.toString());
  const amount1Uint256 = uint256.bnToUint256(params.amount1.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: depositLiquidityLeaf.decoder_and_sanitizer,
    target: depositLiquidityLeaf.target,
    selector: depositLiquidityLeaf.selector,
    calldata: [
      amount0Uint256.low.toString(),
      amount0Uint256.high.toString(),
      amount1Uint256.low.toString(),
      amount1Uint256.high.toString(),
    ],
  };
}

export function ekuboWithdrawLiquidity(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: EkuboWithdrawLiquidityParams
): MerkleOperation {
  const withdrawLiquiditySelector = BigInt(
    selector.getSelectorFromName("withdraw_liquidity")
  ).toString();
  const withdrawLiquidityLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === withdrawLiquiditySelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!withdrawLiquidityLeaf) {
    throw new Error(
      "Ekubo withdraw liquidity operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, withdrawLiquidityLeaf.leaf_hash);

  const ratioWadUint256 = uint256.bnToUint256(params.ratioWad.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: withdrawLiquidityLeaf.decoder_and_sanitizer,
    target: withdrawLiquidityLeaf.target,
    selector: withdrawLiquidityLeaf.selector,
    calldata: [
      ratioWadUint256.low.toString(),
      ratioWadUint256.high.toString(),
      params.minToken0.toString(),
      params.minToken1.toString(),
    ],
  };
}

export function ekuboCollectFees(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: EkuboCollectFeesParams
): MerkleOperation {
  const collectFeesSelector = BigInt(
    selector.getSelectorFromName("collect_fees")
  ).toString();
  const collectFeesLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === collectFeesSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!collectFeesLeaf) {
    throw new Error(
      "Ekubo collect fees operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, collectFeesLeaf.leaf_hash);

  return {
    manageProofs: proofs,
    decoderAndSanitizer: collectFeesLeaf.decoder_and_sanitizer,
    target: collectFeesLeaf.target,
    selector: collectFeesLeaf.selector,
    calldata: [],
  };
}

export function ekuboHarvest(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: EkuboHarvestParams
): MerkleOperation {
  const harvestSelector = BigInt(
    selector.getSelectorFromName("harvest")
  ).toString();
  const harvestLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === harvestSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!harvestLeaf) {
    throw new Error("Ekubo harvest operation not found in vault configuration");
  }

  const proofs = getManageProofs(config.tree, harvestLeaf.leaf_hash);

  return {
    manageProofs: proofs,
    decoderAndSanitizer: harvestLeaf.decoder_and_sanitizer,
    target: harvestLeaf.target,
    selector: harvestLeaf.selector,
    calldata: [
      params.rewardContract,
      params.amount.toString(),
      params.proof.length.toString(),
      ...params.proof,
      params.rewardToken,
    ],
  };
}
