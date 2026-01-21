import { uint256 } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  BridgeTokenHyperlaneMiddlewareParams,
} from "../types";

// Note: claim_token is permissionless - call directly on middleware contract

export function bridgeTokenHyperlaneMiddleware(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: BridgeTokenHyperlaneMiddlewareParams
): MerkleOperation {
  // Convert recipient string to u256
  const recipientUint256 = uint256.bnToUint256(params.recipient.toString());

  // Convert hex to decimal strings for comparison
  const recipientLowDecimal = BigInt(recipientUint256.low).toString();
  const recipientHighDecimal = BigInt(recipientUint256.high).toString();

  // Find the Hyperlane bridge leaf by matching argument addresses
  const hyperlaneLeaf = config.leafs.find(
    (leaf) =>
      leaf.argument_addresses.length >= 5 &&
      BigInt(leaf.argument_addresses[0]) === BigInt(params.source_token) &&
      BigInt(leaf.argument_addresses[1]) === BigInt(params.destination_token) &&
      BigInt(leaf.argument_addresses[2]) ===
        BigInt(params.destination_domain) &&
      BigInt(leaf.argument_addresses[3]) === BigInt(recipientLowDecimal) &&
      BigInt(leaf.argument_addresses[4]) === BigInt(recipientHighDecimal)
  );

  if (!hyperlaneLeaf) {
    throw new Error(
      "Hyperlane bridge operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, hyperlaneLeaf.leaf_hash);

  const amountUint256 = uint256.bnToUint256(params.amount.toString());
  const feeUint256 = uint256.bnToUint256(params.strk_fee.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: hyperlaneLeaf.decoder_and_sanitizer,
    target: hyperlaneLeaf.target,
    selector: hyperlaneLeaf.selector,
    calldata: [
      params.source_token,
      params.destination_token,
      params.destination_domain.toString(),
      recipientLowDecimal,
      recipientHighDecimal,
      amountUint256.low.toString(),
      amountUint256.high.toString(),
      feeUint256.low.toString(),
      feeUint256.high.toString(),
    ],
  };
}
