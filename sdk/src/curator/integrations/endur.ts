import { CallData, byteArray, selector, uint256 } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  EndurDepositWithReferralParams,
  EndurClaimWithdrawalParams,
} from "../types";

// Note: deposit / withdraw / redeem on an Endur LST use the ERC4626 operations.
// withdraw and redeem mint a withdraw queue NFT to the receiver instead of sending assets.

export function endurDepositWithReferral(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: EndurDepositWithReferralParams
): MerkleOperation {
  const depositWithReferralSelector = BigInt(
    selector.getSelectorFromName("deposit_with_referral")
  ).toString();
  const depositWithReferralLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === depositWithReferralSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!depositWithReferralLeaf) {
    throw new Error(
      "Endur deposit with referral operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(
    config.tree,
    depositWithReferralLeaf.leaf_hash
  );

  return {
    manageProofs: proofs,
    decoderAndSanitizer: depositWithReferralLeaf.decoder_and_sanitizer,
    target: depositWithReferralLeaf.target,
    selector: depositWithReferralLeaf.selector,
    calldata: CallData.compile({
      assets: uint256.bnToUint256(params.assets.toString()),
      receiver: params.receiver,
      referral: byteArray.byteArrayFromString(params.referral),
    }),
  };
}

export function endurClaimWithdrawal(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: EndurClaimWithdrawalParams
): MerkleOperation {
  const claimWithdrawalSelector = BigInt(
    selector.getSelectorFromName("claim_withdrawal")
  ).toString();
  const claimWithdrawalLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === claimWithdrawalSelector &&
      BigInt(leaf.target) === BigInt(params.target)
  );

  if (!claimWithdrawalLeaf) {
    throw new Error(
      "Endur claim withdrawal operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, claimWithdrawalLeaf.leaf_hash);

  return {
    manageProofs: proofs,
    decoderAndSanitizer: claimWithdrawalLeaf.decoder_and_sanitizer,
    target: claimWithdrawalLeaf.target,
    selector: claimWithdrawalLeaf.selector,
    calldata: [BigInt(params.request_id).toString()],
  };
}
