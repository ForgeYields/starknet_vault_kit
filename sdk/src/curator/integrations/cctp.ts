import { uint256 } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  BridgeTokenCctpMiddlewareParams,
} from "../types";

// Note: claim_token is permissionless - call directly on middleware contract

export function bridgeTokenCctpMiddleware(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: BridgeTokenCctpMiddlewareParams
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
      BigInt(leaf.argument_addresses[0]) ===
        BigInt(params.destination_domain) &&
      BigInt(leaf.argument_addresses[1]) === BigInt(mintRecipientLowDecimal) &&
      BigInt(leaf.argument_addresses[2]) === BigInt(mintRecipientHighDecimal) &&
      BigInt(leaf.argument_addresses[3]) === BigInt(params.burn_token) &&
      BigInt(leaf.argument_addresses[4]) === BigInt(params.token_to_claim) &&
      BigInt(leaf.argument_addresses[5]) ===
        BigInt(destinationCallerLowDecimal) &&
      BigInt(leaf.argument_addresses[6]) ===
        BigInt(destinationCallerHighDecimal)
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
