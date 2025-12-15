import { Call, uint256, hash, selector } from "starknet";
import * as fs from "fs";

// Re-export all types
export * from "./types";

// Import integration modules
import * as erc4626 from "./integrations/erc4626";
import * as avnu from "./integrations/avnu";
import * as starkgate from "./integrations/starkgate";
import * as hyperlane from "./integrations/hyperlane";
import * as cctp from "./integrations/cctp";
import * as vesu from "./integrations/vesu";
import * as ekubo from "./integrations/ekubo";

import {
  VaultConfigData,
  MerkleOperation,
  BringLiquidityParams,
  ApproveParams,
  DepositParams,
  MintParams,
  WithdrawParams,
  RedeemParams,
  MultiRouteSwapParams,
  RequestRedeemParams,
  ClaimRedeemParams,
  BridgeTokenStarkgateParams,
  ClaimTokenStarkgateParams,
  BridgeTokenHyperlaneParams,
  ClaimTokenHyperlaneParams,
  BridgeTokenCctpParams,
  ClaimTokenCctpParams,
  ModifyPositionParamsV2,
  EkuboDepositLiquidityParams,
  EkuboWithdrawLiquidityParams,
  EkuboCollectFeesParams,
  EkuboHarvestParams,
} from "./types";

export class VaultCuratorSDK {
  private config: VaultConfigData;

  constructor(config: VaultConfigData) {
    this.config = config;
  }

  static fromFile(configPath: string): VaultCuratorSDK {
    const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
    return new VaultCuratorSDK(config);
  }

  // ============================================
  // Core methods
  // ============================================

  public buildCall(operations: MerkleOperation[]): Call {
    if (operations.length === 0) {
      throw new Error("No operations provided");
    }

    const manageProofs: string[] = [];
    const decodersAndSanitizers: string[] = [];
    const targets: string[] = [];
    const selectors: string[] = [];
    const calldatas: string[] = [];

    for (const op of operations) {
      manageProofs.push(op.manageProofs.length.toString(), ...op.manageProofs);
      decodersAndSanitizers.push(op.decoderAndSanitizer);
      targets.push(op.target);
      selectors.push(op.selector);
      calldatas.push(op.calldata.length.toString(), ...op.calldata);
    }

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        operations.length.toString(),
        ...manageProofs,
        operations.length.toString(),
        ...decodersAndSanitizers,
        operations.length.toString(),
        ...targets,
        operations.length.toString(),
        ...selectors,
        operations.length.toString(),
        ...calldatas,
      ],
    };
  }

  public getManageProofs(tree: Array<string[]>, leafHash: string): string[] {
    const proof: string[] = [];
    let currentHash = leafHash;

    // Check if leaf hash exists at level 0 (leaf level)
    const leafLevel = tree[0];
    if (!leafLevel.includes(currentHash)) {
      throw new Error("❌ Leaf hash not found at level 0 of the Merkle tree");
    }

    // Generate proof by traversing up the tree from level 0
    for (let level = 0; level < tree.length - 1; level++) {
      const layer = tree[level];
      const index = layer.indexOf(currentHash);

      if (index === -1) {
        throw new Error(`❌ Hash ${currentHash} not found at level ${level}`);
      }

      const siblingIndex = index % 2 === 0 ? index + 1 : index - 1;

      if (siblingIndex >= layer.length) {
        throw new Error(`❌ No sibling for index ${index} at level ${level}`);
      }

      const sibling = layer[siblingIndex];
      proof.push(sibling);

      // Calculate parent hash for next level - using commutative hash, order doesn't matter
      currentHash = this.hashPair(currentHash, sibling);
    }

    return proof;
  }

  public hashPair(a: string, b: string): string {
    // Use commutative Pedersen hash - sort inputs first to ensure commutativity
    const aBig = BigInt(a);
    const bBig = BigInt(b);
    const [first, second] = aBig < bBig ? [a, b] : [b, a];

    const result = hash.computePedersenHashOnElements([first, second]);
    // Convert from hex to decimal string
    return BigInt(result).toString();
  }

  // ============================================
  // Generic operations
  // ============================================

  public bringLiquidity(params: BringLiquidityParams): MerkleOperation {
    const bringLiquidityLeaf = this.config.leafs.find((leaf) =>
      leaf.description.toLowerCase().includes("bring liquidity")
    );

    if (!bringLiquidityLeaf) {
      throw new Error(
        "Bring liquidity operation not found in vault configuration"
      );
    }

    const proofs = this.getManageProofs(
      this.config.tree,
      bringLiquidityLeaf.leaf_hash
    );

    const amountUint256 = uint256.bnToUint256(params.amount.toString());

    return {
      manageProofs: proofs,
      decoderAndSanitizer: bringLiquidityLeaf.decoder_and_sanitizer,
      target: bringLiquidityLeaf.target,
      selector: bringLiquidityLeaf.selector,
      calldata: [amountUint256.low.toString(), amountUint256.high.toString()],
    };
  }

  public approve(approveParams: ApproveParams): MerkleOperation {
    const approveSelector = BigInt(
      selector.getSelectorFromName("approve")
    ).toString();
    const approveLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === approveSelector &&
        leaf.target === approveParams.target &&
        leaf.argument_addresses.includes(approveParams.spender)
    );
    if (!approveLeaf) {
      throw new Error("Approve operation not found in vault configuration");
    }

    const proofs = this.getManageProofs(
      this.config.tree,
      approveLeaf.leaf_hash
    );
    const amountUint256 = uint256.bnToUint256(approveParams.amount.toString());

    return {
      manageProofs: proofs,
      decoderAndSanitizer: approveLeaf.decoder_and_sanitizer,
      target: approveLeaf.target,
      selector: approveLeaf.selector,
      calldata: [
        approveParams.spender,
        amountUint256.low.toString(),
        amountUint256.high.toString(),
      ],
    };
  }

  // ============================================
  // ERC4626 operations
  // ============================================

  public deposit(params: DepositParams): MerkleOperation {
    return erc4626.deposit(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public mint(params: MintParams): MerkleOperation {
    return erc4626.mint(this.config, this.getManageProofs.bind(this), params);
  }

  public withdraw(params: WithdrawParams): MerkleOperation {
    return erc4626.withdraw(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public redeem(params: RedeemParams): MerkleOperation {
    return erc4626.redeem(this.config, this.getManageProofs.bind(this), params);
  }

  public requestRedeem(params: RequestRedeemParams): MerkleOperation {
    return erc4626.requestRedeem(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public claimRedeem(params: ClaimRedeemParams): MerkleOperation {
    return erc4626.claimRedeem(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  // ============================================
  // AVNU swap
  // ============================================

  public multiRouteSwap(params: MultiRouteSwapParams): MerkleOperation {
    return avnu.multiRouteSwap(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  // ============================================
  // Starkgate bridge
  // ============================================

  public bridgeTokenStarkgate(
    params: BridgeTokenStarkgateParams
  ): MerkleOperation {
    return starkgate.bridgeTokenStarkgate(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public claimTokenStarkgate(
    params: ClaimTokenStarkgateParams = {}
  ): MerkleOperation {
    return starkgate.claimTokenStarkgate(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  // ============================================
  // Hyperlane bridge
  // ============================================

  public bridgeTokenHyperlane(
    params: BridgeTokenHyperlaneParams
  ): MerkleOperation {
    return hyperlane.bridgeTokenHyperlane(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public claimTokenHyperlane(
    params: ClaimTokenHyperlaneParams
  ): MerkleOperation {
    return hyperlane.claimTokenHyperlane(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  // ============================================
  // CCTP bridge
  // ============================================

  public bridgeTokenCctp(params: BridgeTokenCctpParams): MerkleOperation {
    return cctp.bridgeTokenCctp(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public claimTokenCctp(params: ClaimTokenCctpParams): MerkleOperation {
    return cctp.claimTokenCctp(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  // ============================================
  // Vesu V2
  // ============================================

  public modifyPositionV2(params: ModifyPositionParamsV2): MerkleOperation {
    return vesu.modifyPositionV2(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  // ============================================
  // Ekubo LP
  // ============================================

  public ekuboDepositLiquidity(
    params: EkuboDepositLiquidityParams
  ): MerkleOperation {
    return ekubo.ekuboDepositLiquidity(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public ekuboWithdrawLiquidity(
    params: EkuboWithdrawLiquidityParams
  ): MerkleOperation {
    return ekubo.ekuboWithdrawLiquidity(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public ekuboCollectFees(params: EkuboCollectFeesParams): MerkleOperation {
    return ekubo.ekuboCollectFees(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }

  public ekuboHarvest(params: EkuboHarvestParams): MerkleOperation {
    return ekubo.ekuboHarvest(
      this.config,
      this.getManageProofs.bind(this),
      params
    );
  }
}
