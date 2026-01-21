import { uint256, selector } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  BridgeTokenStarkgateParams,
  BridgeTokenStarkgateMiddlewareParams,
} from "../types";

// Note: claim_token_bridged_back is permissionless - call directly on middleware contract

export function bridgeTokenStarkgate(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: BridgeTokenStarkgateParams
): MerkleOperation {
  const initiateTokenWithdrawSelector = BigInt(
    selector.getSelectorFromName("initiate_token_withdraw")
  ).toString();
  const initiateTokenWithdrawLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === initiateTokenWithdrawSelector &&
      leaf.argument_addresses.some(
        (addr) => BigInt(addr) === BigInt(params.l1_token)
      ) &&
      leaf.argument_addresses.some(
        (addr) => BigInt(addr) === BigInt(params.l1_recipient)
      )
  );

  if (!initiateTokenWithdrawLeaf) {
    throw new Error(
      "Initiate token withdraw operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(
    config.tree,
    initiateTokenWithdrawLeaf.leaf_hash
  );

  const amountUint256 = uint256.bnToUint256(params.amount.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: initiateTokenWithdrawLeaf.decoder_and_sanitizer,
    target: initiateTokenWithdrawLeaf.target,
    selector: initiateTokenWithdrawLeaf.selector,
    calldata: [
      params.l1_token,
      params.l1_recipient,
      amountUint256.low.toString(),
      amountUint256.high.toString(),
    ],
  };
}

export function bridgeTokenStarkgateMiddleware(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: BridgeTokenStarkgateMiddlewareParams
): MerkleOperation {
  const initiateTokenWithdrawSelector = BigInt(
    selector.getSelectorFromName("initiate_token_withdraw")
  ).toString();

  // Find the leaf that matches the middleware interface (has starkgate_token_bridge in argument_addresses)
  const initiateTokenWithdrawLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === initiateTokenWithdrawSelector &&
      leaf.argument_addresses.some(
        (addr) => BigInt(addr) === BigInt(params.starkgate_token_bridge)
      ) &&
      leaf.argument_addresses.some(
        (addr) => BigInt(addr) === BigInt(params.l1_token)
      ) &&
      leaf.argument_addresses.some(
        (addr) => BigInt(addr) === BigInt(params.l1_recipient)
      ) &&
      leaf.argument_addresses.some(
        (addr) => BigInt(addr) === BigInt(params.token_to_claim)
      )
  );

  if (!initiateTokenWithdrawLeaf) {
    throw new Error(
      "Initiate token withdraw (middleware) operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(
    config.tree,
    initiateTokenWithdrawLeaf.leaf_hash
  );

  const amountUint256 = uint256.bnToUint256(params.amount.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: initiateTokenWithdrawLeaf.decoder_and_sanitizer,
    target: initiateTokenWithdrawLeaf.target,
    selector: initiateTokenWithdrawLeaf.selector,
    calldata: [
      params.starkgate_token_bridge,
      params.l1_token,
      params.l1_recipient,
      amountUint256.low.toString(),
      amountUint256.high.toString(),
      params.token_to_claim,
    ],
  };
}
