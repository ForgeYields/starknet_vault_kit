import { uint256, selector } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  ModifyPositionParamsV2,
} from "../types";

export function modifyPositionV2(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: ModifyPositionParamsV2
): MerkleOperation {
  const modifyPositionSelector = BigInt(
    selector.getSelectorFromName("modify_position")
  ).toString();
  const modifyPositionLeaf = config.leafs.find(
    (leaf) =>
      BigInt(leaf.target) === BigInt(params.target) &&
      BigInt(leaf.selector) === BigInt(modifyPositionSelector) &&
      leaf.argument_addresses.length === 3 &&
      BigInt(leaf.argument_addresses[0]) === BigInt(params.collateral_asset) &&
      BigInt(leaf.argument_addresses[1]) === BigInt(params.debt_asset) &&
      BigInt(leaf.argument_addresses[2]) === BigInt(params.user)
  );

  if (!modifyPositionLeaf) {
    throw new Error(
      "Modify position V2 operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, modifyPositionLeaf.leaf_hash);

  // Serialize ModifyPositionParamsV2 according to Cairo implementation
  const collateralAbsUint256 = uint256.bnToUint256(
    params.collateral.value.abs.toString()
  );
  const debtAbsUint256 = uint256.bnToUint256(params.debt.value.abs.toString());

  return {
    manageProofs: proofs,
    decoderAndSanitizer: modifyPositionLeaf.decoder_and_sanitizer,
    target: modifyPositionLeaf.target,
    selector: modifyPositionLeaf.selector,
    calldata: [
      params.collateral_asset,
      params.debt_asset,
      params.user,
      params.collateral.denomination === "Native" ? "0" : "1",
      collateralAbsUint256.low.toString(),
      collateralAbsUint256.high.toString(),
      params.collateral.value.is_negative ? "1" : "0",
      params.debt.denomination === "Native" ? "0" : "1",
      debtAbsUint256.low.toString(),
      debtAbsUint256.high.toString(),
      params.debt.value.is_negative ? "1" : "0",
    ],
  };
}
