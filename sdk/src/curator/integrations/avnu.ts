import { uint256, selector } from "starknet";
import {
  VaultConfigData,
  MerkleOperation,
  MultiRouteSwapParams,
} from "../types";

export function multiRouteSwap(
  config: VaultConfigData,
  getManageProofs: (tree: Array<string[]>, leafHash: string) => string[],
  params: MultiRouteSwapParams
): MerkleOperation {
  const multiRouteSwapSelector = BigInt(
    selector.getSelectorFromName("multi_route_swap")
  ).toString();
  const swapLeaf = config.leafs.find(
    (leaf) =>
      leaf.selector === multiRouteSwapSelector &&
      leaf.target === params.target &&
      leaf.argument_addresses.length === 3 &&
      leaf.argument_addresses[0] === params.sell_token_address &&
      leaf.argument_addresses[1] === params.buy_token_address &&
      leaf.argument_addresses[2] === config.metadata.vault_allocator
  );

  if (!swapLeaf) {
    throw new Error(
      "Multi route swap operation not found in vault configuration"
    );
  }

  const proofs = getManageProofs(config.tree, swapLeaf.leaf_hash);

  const sellAmountUint256 = uint256.bnToUint256(
    params.sell_token_amount.toString()
  );
  const buyAmountUint256 = uint256.bnToUint256(
    params.buy_token_amount.toString()
  );
  const buyMinAmountUint256 = uint256.bnToUint256(
    params.buy_token_min_amount.toString()
  );

  // Serialize routes array
  const routesCalldata: string[] = [];
  routesCalldata.push(params.routes.length.toString());

  for (const route of params.routes) {
    routesCalldata.push(route.sell_token);
    routesCalldata.push(route.buy_token);
    routesCalldata.push(route.exchange_address);
    routesCalldata.push(route.percent.toString());
    routesCalldata.push(route.additional_swap_params.length.toString());
    routesCalldata.push(...route.additional_swap_params);
  }

  return {
    manageProofs: proofs,
    decoderAndSanitizer: swapLeaf.decoder_and_sanitizer,
    target: swapLeaf.target,
    selector: swapLeaf.selector,
    calldata: [
      params.sell_token_address,
      sellAmountUint256.low.toString(),
      sellAmountUint256.high.toString(),
      params.buy_token_address,
      buyAmountUint256.low.toString(),
      buyAmountUint256.high.toString(),
      buyMinAmountUint256.low.toString(),
      buyMinAmountUint256.high.toString(),
      params.beneficiary,
      params.integrator_fee_amount_bps.toString(),
      params.integrator_fee_recipient,
      ...routesCalldata,
    ],
  };
}
