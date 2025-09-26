import { Call, BigNumberish, uint256, hash, selector } from "starknet";
import * as fs from "fs";

export interface VaultConfigData {
  metadata: {
    vault: string;
    underlying_asset: string;
    vault_allocator: string;
    manager: string;
    root: string;
    tree_capacity: number;
    leaf_used: number;
  };
  leafs: Array<{
    decoder_and_sanitizer: string;
    target: string;
    selector: string;
    argument_addresses: string[];
    description: string;
    leaf_index: number;
    leaf_hash: string;
  }>;
  tree: Array<string[]>;
}

export interface BringLiquidityParams {
  amount: BigNumberish;
}

export interface ApproveParams {
  target: string;
  spender: string;
  amount: BigNumberish;
}

export interface DepositParams {
  target: string;
  assets: BigNumberish;
  receiver: string;
}

export interface MintParams {
  target: string;
  shares: BigNumberish;
  receiver: string;
}

export interface WithdrawParams {
  target: string;
  assets: BigNumberish;
  receiver: string;
  owner: string;
}

export interface RedeemParams {
  target: string;
  shares: BigNumberish;
  receiver: string;
  owner: string;
}

export interface Route {
  sell_token: string;
  buy_token: string;
  exchange_address: string;
  percent: BigNumberish;
  additional_swap_params: string[];
}

export interface MultiRouteSwapParamsInput {
  target: string;
  sell_token_address: string;
  sell_token_amount: BigNumberish;
  buy_token_address: string;
  buy_token_amount: BigNumberish;
  buy_token_min_amount: BigNumberish;
  integrator_fee_amount_bps: BigNumberish;
  integrator_fee_recipient: string;
  routes: Route[];
}

export interface MultiRouteSwapParams extends MultiRouteSwapParamsInput {
  beneficiary: string;
}

export interface RequestRedeemParams {
  target: string;
  shares: BigNumberish;
  receiver: string;
  owner: string;
}

export interface ClaimRedeemParams {
  target: string;
  id: BigNumberish;
}

export interface i257 {
  abs: BigNumberish;
  is_negative: boolean;
}

export interface Amount {
  amount_type: "Delta" | "Target";
  denomination: "Native" | "Assets";
  value: i257;
}

export interface AmountV2 {
  denomination: "Native" | "Assets";
  value: i257;
}

export interface ModifyPositionV1ParamsInput {
  target: string;
  pool_id: string;
  collateral_asset: string;
  debt_asset: string;
  collateral: Amount;
  debt: Amount;
  data: string[];
}

export interface ModifyPositionV1Params extends ModifyPositionV1ParamsInput {
  user: string;
}

export interface ModifyPositionParamsV2Input {
  target: string;
  collateral_asset: string;
  debt_asset: string;
  collateral: AmountV2;
  debt: AmountV2;
}

export interface ModifyPositionParamsV2 extends ModifyPositionParamsV2Input {
  user: string;
}

export class VaultCuratorSDK {
  private config: VaultConfigData;

  constructor(config: VaultConfigData) {
    this.config = config;
  }

  static fromFile(configPath: string): VaultCuratorSDK {
    const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
    return new VaultCuratorSDK(config);
  }

  public bringLiquidity(params: BringLiquidityParams): Call {
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
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        bringLiquidityLeaf.decoder_and_sanitizer,
        "1", // targets array length
        bringLiquidityLeaf.target,
        "1", // selectors array length
        bringLiquidityLeaf.selector,
        "1", // calldatas array length
        "2", // calldata length (uint256 = 2 slots)
        amountUint256.low.toString(),
        amountUint256.high.toString(),
      ],
    };
  }

  public approve(approveParams: ApproveParams): Call {
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
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(),
        ...proofs,
        "1", // decoder_and_sanitizers array length
        approveLeaf.decoder_and_sanitizer,
        "1", // targets array length
        approveLeaf.target,
        "1", // selectors array length
        approveLeaf.selector,
        "1", // calldatas array length
        "3", // calldata length (spender + uint256 = 3 slots)
        approveParams.spender,
        amountUint256.low.toString(),
        amountUint256.high.toString(),
      ],
    };
  }

  bringLiquidityHelper(shouldApprove: boolean, amount: BigNumberish): Call[] {
    const calls: Call[] = [];
    if (shouldApprove) {
      calls.push(
        this.approve({
          target: this.config.metadata.underlying_asset,
          spender: this.config.metadata.vault,
          amount,
        })
      );
    }
    calls.push(this.bringLiquidity({ amount }));
    return calls;
  }

  depositHelper(params: DepositParams & { withApproval?: boolean }): Call[] {
    const calls: Call[] = [];

    if (params.withApproval) {
      calls.push(
        this.approve({
          target: this.config.metadata.underlying_asset,
          spender: params.target,
          amount: params.assets,
        })
      );
    }

    calls.push(this.deposit(params));
    return calls;
  }

  mintHelper(params: MintParams & { withApproval?: boolean }): Call[] {
    const calls: Call[] = [];

    if (params.withApproval) {
      calls.push(
        this.approve({
          target: this.config.metadata.underlying_asset,
          spender: this.config.metadata.vault,
          amount: params.shares,
        })
      );
    }

    calls.push(this.mint(params));
    return calls;
  }

  withdrawHelper(target: string, assets: BigNumberish): Call[] {
    return [
      this.withdraw({
        target,
        assets,
        receiver: this.config.metadata.vault,
        owner: this.config.metadata.vault,
      }),
    ];
  }

  redeemHelper(target: string, shares: BigNumberish): Call[] {
    return [
      this.redeem({
        target,
        shares,
        receiver: this.config.metadata.vault,
        owner: this.config.metadata.vault,
      }),
    ];
  }

  multiRouteSwapHelper(
    params: MultiRouteSwapParamsInput,
    { withApproval }: { withApproval?: boolean } = { withApproval: true }
  ): Call[] {
    const calls: Call[] = [];
    if (withApproval) {
      calls.push(
        this.approve({
          target: params.sell_token_address,
          spender: params.target,
          amount: params.sell_token_amount,
        })
      );
    }
    calls.push(
      this.multiRouteSwap({
        ...params,
        beneficiary: this.config.metadata.vault,
      })
    );
    return calls;
  }

  public requestRedeemHelper(target: string, shares: BigNumberish): Call[] {
    return [
      this.requestRedeem({
        target,
        shares,
        receiver: this.config.metadata.vault,
        owner: this.config.metadata.vault,
      }),
    ];
  }

  public ModifyPositionV1Helper(
    params: ModifyPositionV1ParamsInput,
    withApprovalCall?: ApproveParams
  ): Call[] {
    const calls: Call[] = [];

    if (withApprovalCall) {
      calls.push(this.approve(withApprovalCall));
    }
    calls.push(
      this.modifyPositionV1({ ...params, user: this.config.metadata.vault })
    );
    return calls;
  }

  public ModifyPositionV2Helper(
    params: ModifyPositionParamsV2Input,
    withApprovalCall?: ApproveParams
  ): Call[] {
    const calls: Call[] = [];

    if (withApprovalCall) {
      calls.push(this.approve(withApprovalCall));
    }
    calls.push(
      this.modifyPositionV2({ ...params, user: this.config.metadata.vault })
    );
    return calls;
  }

  public deposit(params: DepositParams): Call {
    const depositSelector = BigInt(
      selector.getSelectorFromName("deposit")
    ).toString();
    const depositLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === depositSelector && leaf.target === params.target
    );

    if (!depositLeaf) {
      throw new Error("Deposit operation not found in vault configuration");
    }

    const proofs = this.getManageProofs(
      this.config.tree,
      depositLeaf.leaf_hash
    );

    const assetsUint256 = uint256.bnToUint256(params.assets.toString());

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        depositLeaf.decoder_and_sanitizer,
        "1", // targets array length
        depositLeaf.target,
        "1", // selectors array length
        depositLeaf.selector,
        "1", // calldatas array length
        "3", // calldata length (uint256 + address = 3 slots)
        assetsUint256.low.toString(),
        assetsUint256.high.toString(),
        params.receiver,
      ],
    };
  }

  public mint(params: MintParams): Call {
    const mintSelector = BigInt(
      selector.getSelectorFromName("mint")
    ).toString();
    const mintLeaf = this.config.leafs.find(
      (leaf) => leaf.selector === mintSelector && leaf.target === params.target
    );

    if (!mintLeaf) {
      throw new Error("Mint operation not found in vault configuration");
    }

    const proofs = this.getManageProofs(this.config.tree, mintLeaf.leaf_hash);

    const sharesUint256 = uint256.bnToUint256(params.shares.toString());

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        mintLeaf.decoder_and_sanitizer,
        "1", // targets array length
        mintLeaf.target,
        "1", // selectors array length
        mintLeaf.selector,
        "1", // calldatas array length
        "3", // calldata length (uint256 + address = 3 slots)
        sharesUint256.low.toString(),
        sharesUint256.high.toString(),
        params.receiver,
      ],
    };
  }

  public withdraw(params: WithdrawParams): Call {
    const withdrawSelector = BigInt(
      selector.getSelectorFromName("withdraw")
    ).toString();
    const withdrawLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === withdrawSelector && leaf.target === params.target
    );

    if (!withdrawLeaf) {
      throw new Error("Withdraw operation not found in vault configuration");
    }

    const proofs = this.getManageProofs(
      this.config.tree,
      withdrawLeaf.leaf_hash
    );

    const assetsUint256 = uint256.bnToUint256(params.assets.toString());

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        withdrawLeaf.decoder_and_sanitizer,
        "1", // targets array length
        withdrawLeaf.target,
        "1", // selectors array length
        withdrawLeaf.selector,
        "1", // calldatas array length
        "4", // calldata length (uint256 + 2 addresses = 4 slots)
        assetsUint256.low.toString(),
        assetsUint256.high.toString(),
        params.receiver,
        params.owner,
      ],
    };
  }

  public redeem(params: RedeemParams): Call {
    const redeemSelector = BigInt(
      selector.getSelectorFromName("redeem")
    ).toString();
    const redeemLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === redeemSelector && leaf.target === params.target
    );

    if (!redeemLeaf) {
      throw new Error("Redeem operation not found in vault configuration");
    }

    const proofs = this.getManageProofs(this.config.tree, redeemLeaf.leaf_hash);

    const sharesUint256 = uint256.bnToUint256(params.shares.toString());

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        redeemLeaf.decoder_and_sanitizer,
        "1", // targets array length
        redeemLeaf.target,
        "1", // selectors array length
        redeemLeaf.selector,
        "1", // calldatas array length
        "4", // calldata length (uint256 + 2 addresses = 4 slots)
        sharesUint256.low.toString(),
        sharesUint256.high.toString(),
        params.receiver,
        params.owner,
      ],
    };
  }

  public multiRouteSwap(params: MultiRouteSwapParams): Call {
    const multiRouteSwapSelector = BigInt(
      selector.getSelectorFromName("multi_route_swap")
    ).toString();
    const swapLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === multiRouteSwapSelector &&
        leaf.target === params.target
    );

    if (!swapLeaf) {
      throw new Error(
        "Multi route swap operation not found in vault configuration"
      );
    }

    const proofs = this.getManageProofs(this.config.tree, swapLeaf.leaf_hash);

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
    routesCalldata.push(params.routes.length.toString()); // routes array length

    for (const route of params.routes) {
      routesCalldata.push(route.sell_token);
      routesCalldata.push(route.buy_token);
      routesCalldata.push(route.exchange_address);
      const percentUint256 = uint256.bnToUint256(route.percent.toString());
      routesCalldata.push(percentUint256.low.toString());
      routesCalldata.push(percentUint256.high.toString());
      routesCalldata.push(route.additional_swap_params.length.toString());
      routesCalldata.push(...route.additional_swap_params);
    }

    const calldata = [
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
    ];

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        swapLeaf.decoder_and_sanitizer,
        "1", // targets array length
        swapLeaf.target,
        "1", // selectors array length
        swapLeaf.selector,
        "1", // calldatas array length
        calldata.length.toString(),
        ...calldata,
      ],
    };
  }

  public requestRedeem(params: RequestRedeemParams): Call {
    const requestRedeemSelector = BigInt(
      selector.getSelectorFromName("request_redeem")
    ).toString();
    const requestRedeemLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === requestRedeemSelector && leaf.target === params.target
    );

    if (!requestRedeemLeaf) {
      throw new Error(
        "Request redeem operation not found in vault configuration"
      );
    }

    const proofs = this.getManageProofs(
      this.config.tree,
      requestRedeemLeaf.leaf_hash
    );

    const sharesUint256 = uint256.bnToUint256(params.shares.toString());

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        requestRedeemLeaf.decoder_and_sanitizer,
        "1", // targets array length
        requestRedeemLeaf.target,
        "1", // selectors array length
        requestRedeemLeaf.selector,
        "1", // calldatas array length
        "4", // calldata length (uint256 + 2 addresses = 4 slots)
        sharesUint256.low.toString(),
        sharesUint256.high.toString(),
        params.receiver,
        params.owner,
      ],
    };
  }

  public claimRedeem(params: ClaimRedeemParams): Call {
    const claimRedeemSelector = BigInt(
      selector.getSelectorFromName("claim_redeem")
    ).toString();
    const claimRedeemLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === claimRedeemSelector && leaf.target === params.target
    );

    if (!claimRedeemLeaf) {
      throw new Error(
        "Claim redeem operation not found in vault configuration"
      );
    }

    const proofs = this.getManageProofs(
      this.config.tree,
      claimRedeemLeaf.leaf_hash
    );

    const idUint256 = uint256.bnToUint256(params.id.toString());

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        claimRedeemLeaf.decoder_and_sanitizer,
        "1", // targets array length
        claimRedeemLeaf.target,
        "1", // selectors array length
        claimRedeemLeaf.selector,
        "1", // calldatas array length
        "2", // calldata length (uint256 = 2 slots)
        idUint256.low.toString(),
        idUint256.high.toString(),
      ],
    };
  }

  public modifyPositionV1(params: ModifyPositionV1Params): Call {
    const modifyPositionSelector = BigInt(
      selector.getSelectorFromName("modify_position")
    ).toString();
    const modifyPositionLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === modifyPositionSelector &&
        leaf.target === params.target
    );

    if (!modifyPositionLeaf) {
      throw new Error(
        "Modify position operation not found in vault configuration"
      );
    }

    const proofs = this.getManageProofs(
      this.config.tree,
      modifyPositionLeaf.leaf_hash
    );

    // Serialize ModifyPositionParams according to Cairo implementation
    const collateralAbsUint256 = uint256.bnToUint256(
      params.collateral.value.abs.toString()
    );
    const debtAbsUint256 = uint256.bnToUint256(
      params.debt.value.abs.toString()
    );

    const calldata = [
      params.pool_id,
      params.collateral_asset,
      params.debt_asset,
      params.user,
      // collateral Amount
      params.collateral.amount_type === "Delta" ? "0" : "1", // AmountType enum
      params.collateral.denomination === "Native" ? "0" : "1", // AmountDenomination enum
      // collateral i257 value
      collateralAbsUint256.low.toString(),
      collateralAbsUint256.high.toString(),
      params.collateral.value.is_negative ? "1" : "0",
      // debt Amount
      params.debt.amount_type === "Delta" ? "0" : "1",
      params.debt.denomination === "Native" ? "0" : "1",
      // debt i257 value
      debtAbsUint256.low.toString(),
      debtAbsUint256.high.toString(),
      params.debt.value.is_negative ? "1" : "0",
      // data array
      params.data.length.toString(),
      ...params.data,
    ];

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        modifyPositionLeaf.decoder_and_sanitizer,
        "1", // targets array length
        modifyPositionLeaf.target,
        "1", // selectors array length
        modifyPositionLeaf.selector,
        "1", // calldatas array length
        calldata.length.toString(),
        ...calldata,
      ],
    };
  }

  public modifyPositionV2(params: ModifyPositionParamsV2): Call {
    const modifyPositionSelector = BigInt(
      selector.getSelectorFromName("modify_position")
    ).toString();
    const modifyPositionLeaf = this.config.leafs.find(
      (leaf) =>
        leaf.selector === modifyPositionSelector &&
        leaf.target === params.target
    );

    if (!modifyPositionLeaf) {
      throw new Error(
        "Modify position V2 operation not found in vault configuration"
      );
    }

    const proofs = this.getManageProofs(
      this.config.tree,
      modifyPositionLeaf.leaf_hash
    );

    // Serialize ModifyPositionParamsV2 according to Cairo implementation
    const collateralAbsUint256 = uint256.bnToUint256(
      params.collateral.value.abs.toString()
    );
    const debtAbsUint256 = uint256.bnToUint256(
      params.debt.value.abs.toString()
    );

    const calldata = [
      params.collateral_asset,
      params.debt_asset,
      params.user,
      // collateral AmountV2
      params.collateral.denomination === "Native" ? "0" : "1", // AmountDenomination enum
      // collateral i257 value
      collateralAbsUint256.low.toString(),
      collateralAbsUint256.high.toString(),
      params.collateral.value.is_negative ? "1" : "0",
      // debt AmountV2
      params.debt.denomination === "Native" ? "0" : "1",
      // debt i257 value
      debtAbsUint256.low.toString(),
      debtAbsUint256.high.toString(),
      params.debt.value.is_negative ? "1" : "0",
    ];

    return {
      contractAddress: this.config.metadata.manager,
      entrypoint: "manage_vault_with_merkle_verification",
      calldata: [
        "1", // proofs array length
        proofs.length.toString(), // proof length
        ...proofs,
        "1", // decoder_and_sanitizers array length
        modifyPositionLeaf.decoder_and_sanitizer,
        "1", // targets array length
        modifyPositionLeaf.target,
        "1", // selectors array length
        modifyPositionLeaf.selector,
        "1", // calldatas array length
        calldata.length.toString(),
        ...calldata,
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
}
