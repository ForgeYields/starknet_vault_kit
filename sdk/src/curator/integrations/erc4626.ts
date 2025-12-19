import { uint256, selector } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  DepositParams,
  MintParams,
  WithdrawParams,
  RedeemParams,
  RequestRedeemParams,
  ClaimRedeemParams,
} from "../types";

export function deposit(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: DepositParams
): MerkleOperation {
  const depositSelector = BigInt(
    selector.getSelectorFromName("deposit")
  ).toString();
  const depositLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === depositSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!depositLeaf) {
    throw new Error("Deposit operation not found in vault configuration");
  }

  const proofs = getManageProofs(config.tree, depositLeaf.leaf_hash);
  const assetsUint256 = uint256.bnToUint256(params.assets.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: depositLeaf.decoder_and_sanitizer,
    target: depositLeaf.target,
    selector: depositLeaf.selector,
    calldata: [
      assetsUint256.low.toString(),
      assetsUint256.high.toString(),
      params.receiver,
    ],
  };
}

export function mint(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: MintParams
): MerkleOperation {
  const mintSelector = BigInt(selector.getSelectorFromName("mint")).toString();
  const mintLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === mintSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!mintLeaf) {
    throw new Error("Mint operation not found in vault configuration");
  }

  const proofs = getManageProofs(config.tree, mintLeaf.leaf_hash);
  const sharesUint256 = uint256.bnToUint256(params.shares.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: mintLeaf.decoder_and_sanitizer,
    target: mintLeaf.target,
    selector: mintLeaf.selector,
    calldata: [
      sharesUint256.low.toString(),
      sharesUint256.high.toString(),
      params.receiver,
    ],
  };
}

export function withdraw(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: WithdrawParams
): MerkleOperation {
  const withdrawSelector = BigInt(
    selector.getSelectorFromName("withdraw")
  ).toString();
  const withdrawLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === withdrawSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!withdrawLeaf) {
    throw new Error("Withdraw operation not found in vault configuration");
  }

  const proofs = getManageProofs(config.tree, withdrawLeaf.leaf_hash);
  const assetsUint256 = uint256.bnToUint256(params.assets.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: withdrawLeaf.decoder_and_sanitizer,
    target: withdrawLeaf.target,
    selector: withdrawLeaf.selector,
    calldata: [
      assetsUint256.low.toString(),
      assetsUint256.high.toString(),
      params.receiver,
      params.owner,
    ],
  };
}

export function redeem(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: RedeemParams
): MerkleOperation {
  const redeemSelector = BigInt(
    selector.getSelectorFromName("redeem")
  ).toString();
  const redeemLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === redeemSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!redeemLeaf) {
    throw new Error("Redeem operation not found in vault configuration");
  }

  const proofs = getManageProofs(config.tree, redeemLeaf.leaf_hash);
  const sharesUint256 = uint256.bnToUint256(params.shares.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: redeemLeaf.decoder_and_sanitizer,
    target: redeemLeaf.target,
    selector: redeemLeaf.selector,
    calldata: [
      sharesUint256.low.toString(),
      sharesUint256.high.toString(),
      params.receiver,
      params.owner,
    ],
  };
}

export function requestRedeem(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: RequestRedeemParams
): MerkleOperation {
  const requestRedeemSelector = BigInt(
    selector.getSelectorFromName("request_redeem")
  ).toString();
  const requestRedeemLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === requestRedeemSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!requestRedeemLeaf) {
    throw new Error(
      "Request redeem operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, requestRedeemLeaf.leaf_hash);
  const sharesUint256 = uint256.bnToUint256(params.shares.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: requestRedeemLeaf.decoder_and_sanitizer,
    target: requestRedeemLeaf.target,
    selector: requestRedeemLeaf.selector,
    calldata: [
      sharesUint256.low.toString(),
      sharesUint256.high.toString(),
      params.receiver,
      params.owner,
    ],
  };
}

export function claimRedeem(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: ClaimRedeemParams
): MerkleOperation {
  const claimRedeemSelector = BigInt(
    selector.getSelectorFromName("claim_redeem")
  ).toString();
  const claimRedeemLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === claimRedeemSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!claimRedeemLeaf) {
    throw new Error("Claim redeem operation not found in vault configuration");
  }

  const proofs = getManageProofs(config.tree, claimRedeemLeaf.leaf_hash);
  const idUint256 = uint256.bnToUint256(params.id.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: claimRedeemLeaf.decoder_and_sanitizer,
    target: claimRedeemLeaf.target,
    selector: claimRedeemLeaf.selector,
    calldata: [idUint256.low.toString(), idUint256.high.toString()],
  };
}
