import { uint256, selector } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  BridgeTokenCctpParams,
  ClaimTokenCctpParams,
} from "../types";

export function bridgeTokenCctp(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: BridgeTokenCctpParams
): MerkleOperation {
  // Convert mint_recipient string to u256
  const mintRecipientUint256 = uint256.bnToUint256(
    params.mint_recipient.toString()
  );
  // Convert destination_caller string to u256
  const destinationCallerUint256 = uint256.bnToUint256(
    params.destination_caller.toString()
  );

  // Convert hex to decimal strings for comparison
  const mintRecipientLowDecimal = BigInt(mintRecipientUint256.low).toString();
  const mintRecipientHighDecimal = BigInt(mintRecipientUint256.high).toString();
  const destinationCallerLowDecimal = BigInt(
    destinationCallerUint256.low
  ).toString();
  const destinationCallerHighDecimal = BigInt(
    destinationCallerUint256.high
  ).toString();

  // Find the CCTP deposit_for_burn leaf by matching argument addresses
  const cctpLeaf = config.leafs.find(
    (leaf) =>
      leaf.argument_addresses.length >= 7 &&
      leaf.argument_addresses[0] === params.destination_domain.toString() &&
      leaf.argument_addresses[1] === mintRecipientLowDecimal &&
      leaf.argument_addresses[2] === mintRecipientHighDecimal &&
      leaf.argument_addresses[3] === params.burn_token &&
      leaf.argument_addresses[4] === params.token_to_claim &&
      leaf.argument_addresses[5] === destinationCallerLowDecimal &&
      leaf.argument_addresses[6] === destinationCallerHighDecimal
  );

  if (!cctpLeaf) {
    throw new Error(
      "CCTP deposit_for_burn operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, cctpLeaf.leaf_hash);

  const amountUint256 = uint256.bnToUint256(params.amount.toString());
  const maxFeeUint256 = uint256.bnToUint256(params.max_fee.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: cctpLeaf.decoder_and_sanitizer,
    target: cctpLeaf.target,
    selector: cctpLeaf.selector,
    calldata: [
      amountUint256.low.toString(),
      amountUint256.high.toString(),
      params.destination_domain.toString(),
      mintRecipientLowDecimal,
      mintRecipientHighDecimal,
      params.burn_token,
      params.token_to_claim,
      destinationCallerLowDecimal,
      destinationCallerHighDecimal,
      maxFeeUint256.low.toString(),
      maxFeeUint256.high.toString(),
      params.min_finality_threshold.toString(),
    ],
  };
}

export function claimTokenCctp(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: ClaimTokenCctpParams
): MerkleOperation {
  const claimTokenSelector = BigInt(
    selector.getSelectorFromName("claim_token")
  ).toString();

  // Find the CCTP claim_token leaf by matching the selector and argument addresses
  const claimLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === claimTokenSelector &&
      leaf.argument_addresses.length >= 3 &&
      leaf.argument_addresses[0] === params.burn_token &&
      leaf.argument_addresses[1] === params.token_to_claim &&
      leaf.argument_addresses[2] === params.destination_domain.toString()
  );

  if (!claimLeaf) {
    throw new Error(
      "CCTP claim_token operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, claimLeaf.leaf_hash);

  return {
    manageProofs: proofs,
    decoderAndSanitizer: claimLeaf.decoder_and_sanitizer,
    target: claimLeaf.target,
    selector: claimLeaf.selector,
    calldata: [
      params.burn_token,
      params.token_to_claim,
      params.destination_domain.toString(),
    ],
  };
}
