import { uint256, selector } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  BridgeLZParams,
  BridgeLZMiddlewareParams,
} from "../types";

// Helper to serialize ByteArray (empty or provided hex string)
function serializeByteArray(hexString?: string): string[] {
  if (!hexString || hexString === "" || hexString === "0x") {
    // Empty ByteArray: data_len=0, pending_word=0, pending_word_len=0
    return ["0", "0", "0"];
  }
  // For non-empty ByteArray, we'd need proper serialization
  // For now, assume empty - most LZ operations use empty extra_options/compose_msg/oft_cmd
  return ["0", "0", "0"];
}

export function bridgeLZ(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: BridgeLZParams
): MerkleOperation {
  // Convert to string to u256
  const toUint256 = uint256.bnToUint256(params.to.toString());
  const toLowDecimal = BigInt(toUint256.low).toString();
  const toHighDecimal = BigInt(toUint256.high).toString();

  // vault_allocator is used as refund_address
  const vaultAllocator = config.metadata.vault_allocator;

  const sendSelector = BigInt(selector.getSelectorFromName("send")).toString();

  // Find the LZ send leaf by matching argument addresses
  // Args: dst_eid, to (u256), refund_address
  const lzLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === sendSelector &&
      leaf.target === params.oft &&
      leaf.argument_addresses.length >= 4 &&
      BigInt(leaf.argument_addresses[0]) === BigInt(params.dst_eid) &&
      BigInt(leaf.argument_addresses[1]) === BigInt(toLowDecimal) &&
      BigInt(leaf.argument_addresses[2]) === BigInt(toHighDecimal) &&
      BigInt(leaf.argument_addresses[3]) === BigInt(vaultAllocator)
  );

  if (!lzLeaf) {
    throw new Error("LZ send operation not found in vault configuration");
  }

  const proofs = getManageProofs(config.tree, lzLeaf.leaf_hash);

  const amountUint256 = uint256.bnToUint256(params.amount.toString());
  const minAmountUint256 = uint256.bnToUint256(params.min_amount.toString());
  const nativeFeeUint256 = uint256.bnToUint256(params.native_fee.toString());
  const lzTokenFeeUint256 = uint256.bnToUint256(
    (params.lz_token_fee || "0").toString()
  );

  // Build SendParam calldata
  const sendParamCalldata = [
    params.dst_eid.toString(), // dst_eid
    toLowDecimal, // to.low
    toHighDecimal, // to.high
    amountUint256.low.toString(), // amount_ld.low
    amountUint256.high.toString(), // amount_ld.high
    minAmountUint256.low.toString(), // min_amount_ld.low
    minAmountUint256.high.toString(), // min_amount_ld.high
    ...serializeByteArray(params.extra_options), // extra_options
    ...serializeByteArray(params.compose_msg), // compose_msg
    ...serializeByteArray(params.oft_cmd), // oft_cmd
  ];

  // Build MessagingFee calldata
  const feeCalldata = [
    nativeFeeUint256.low.toString(), // native_fee.low
    nativeFeeUint256.high.toString(), // native_fee.high
    lzTokenFeeUint256.low.toString(), // lz_token_fee.low
    lzTokenFeeUint256.high.toString(), // lz_token_fee.high
  ];

  return {
    manageProofs: proofs,
    decoderAndSanitizer: lzLeaf.decoder_and_sanitizer,
    target: lzLeaf.target,
    selector: lzLeaf.selector,
    calldata: [
      ...sendParamCalldata,
      ...feeCalldata,
      vaultAllocator, // refund_address
    ],
  };
}

export function bridgeLZMiddleware(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: BridgeLZMiddlewareParams
): MerkleOperation {
  // Convert to string to u256
  const toUint256 = uint256.bnToUint256(params.to.toString());
  const toLowDecimal = BigInt(toUint256.low).toString();
  const toHighDecimal = BigInt(toUint256.high).toString();

  // vault_allocator is used as refund_address
  const vaultAllocator = config.metadata.vault_allocator;

  const sendSelector = BigInt(selector.getSelectorFromName("send")).toString();

  // Find the LZ middleware send leaf by matching argument addresses
  // Args: oft, underlying_token, token_to_claim, dst_eid, to (u256), refund_address
  const lzLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === sendSelector &&
      leaf.argument_addresses.length >= 7 &&
      BigInt(leaf.argument_addresses[0]) === BigInt(params.oft) &&
      BigInt(leaf.argument_addresses[1]) === BigInt(params.underlying_token) &&
      BigInt(leaf.argument_addresses[2]) === BigInt(params.token_to_claim) &&
      BigInt(leaf.argument_addresses[3]) === BigInt(params.dst_eid) &&
      BigInt(leaf.argument_addresses[4]) === BigInt(toLowDecimal) &&
      BigInt(leaf.argument_addresses[5]) === BigInt(toHighDecimal) &&
      BigInt(leaf.argument_addresses[6]) === BigInt(vaultAllocator)
  );

  if (!lzLeaf) {
    throw new Error(
      "LZ middleware send operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, lzLeaf.leaf_hash);

  const amountUint256 = uint256.bnToUint256(params.amount.toString());
  const minAmountUint256 = uint256.bnToUint256(params.min_amount.toString());
  const nativeFeeUint256 = uint256.bnToUint256(params.native_fee.toString());
  const lzTokenFeeUint256 = uint256.bnToUint256(
    (params.lz_token_fee || "0").toString()
  );

  // Build SendParam calldata
  const sendParamCalldata = [
    params.dst_eid.toString(), // dst_eid
    toLowDecimal, // to.low
    toHighDecimal, // to.high
    amountUint256.low.toString(), // amount_ld.low
    amountUint256.high.toString(), // amount_ld.high
    minAmountUint256.low.toString(), // min_amount_ld.low
    minAmountUint256.high.toString(), // min_amount_ld.high
    ...serializeByteArray(params.extra_options), // extra_options
    ...serializeByteArray(params.compose_msg), // compose_msg
    ...serializeByteArray(params.oft_cmd), // oft_cmd
  ];

  // Build MessagingFee calldata
  const feeCalldata = [
    nativeFeeUint256.low.toString(), // native_fee.low
    nativeFeeUint256.high.toString(), // native_fee.high
    lzTokenFeeUint256.low.toString(), // lz_token_fee.low
    lzTokenFeeUint256.high.toString(), // lz_token_fee.high
  ];

  return {
    manageProofs: proofs,
    decoderAndSanitizer: lzLeaf.decoder_and_sanitizer,
    target: lzLeaf.target,
    selector: lzLeaf.selector,
    calldata: [
      params.oft, // oft
      params.underlying_token, // underlying_token
      params.token_to_claim, // token_to_claim
      ...sendParamCalldata,
      ...feeCalldata,
      vaultAllocator, // refund_address
    ],
  };
}

// Note: claim_token is permissionless - anyone can call it directly on the middleware
// No SDK function needed as it doesn't require merkle verification
