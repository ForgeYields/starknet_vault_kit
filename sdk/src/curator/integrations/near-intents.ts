import { CallData, byteArray, selector } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  DepositNearIntentsParams,
} from "../types";

// Omni Bridge recipient of every NEAR Intents deposit
const NEAR_INTENTS_RECIPIENT = "near:intents.near";
// Relayer fee taken from the bridged amount, pinned to zero in the merkle leaf
const NEAR_INTENTS_TOKEN_FEE = "0";

export function depositNearIntents(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: DepositNearIntentsParams
): MerkleOperation {
  const initTransferSelector = BigInt(
    selector.getSelectorFromName("init_transfer")
  ).toString();

  // Sanitized arguments: token, fee, recipient (ByteArray), message (ByteArray)
  const sanitizedArguments = CallData.compile({
    token_address: params.token,
    fee: NEAR_INTENTS_TOKEN_FEE,
    recipient: byteArray.byteArrayFromString(NEAR_INTENTS_RECIPIENT),
    message: byteArray.byteArrayFromString(params.intents_account),
  }).map((value) => BigInt(value));

  const initTransferLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === initTransferSelector &&
      BigInt(leaf.target) === BigInt(params.omni_bridge) &&
      leaf.argument_addresses.length === sanitizedArguments.length &&
      leaf.argument_addresses.every(
        (addr, i) => BigInt(addr) === sanitizedArguments[i]
      )
  );

  if (!initTransferLeaf) {
    throw new Error(
      "NEAR Intents deposit operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, initTransferLeaf.leaf_hash);

  return {
    manageProofs: proofs,
    decoderAndSanitizer: initTransferLeaf.decoder_and_sanitizer,
    target: initTransferLeaf.target,
    selector: initTransferLeaf.selector,
    calldata: CallData.compile({
      token_address: params.token,
      amount: params.amount.toString(),
      fee: NEAR_INTENTS_TOKEN_FEE,
      native_fee: params.native_fee.toString(),
      recipient: byteArray.byteArrayFromString(NEAR_INTENTS_RECIPIENT),
      message: byteArray.byteArrayFromString(params.intents_account),
    }),
  };
}
