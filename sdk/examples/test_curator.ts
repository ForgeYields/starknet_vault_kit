/**
 * Comprehensive VaultCuratorSDK Example
 * Demonstrates all available operations in a single test file
 */

import { VaultCuratorSDK } from "../src/curator";

// ============================================
// Token and Contract Addresses (from test.json)
// ============================================
const TOKENS = {
  ETH: "2087021424722619777119509474943472645767659996348769578120564519014510906823",
  USDC: "2368576823837625528275935341135881659748932889268308403712618244410713532584",
  USDT: "2967174050445828070862061291903957281356339325911846264948421066253307482040",
  STRK: "2009894490435840142178314390393166646092438090257831307886760648929397478285",
  WBTC: "1806018566677800621296032626439935115720767031724401394291089442012247156652",
  wstETH: "154717502686997779505242937237748798500912348117963555524611254740330341259",
  SolvBTC: "2522838177878422711967992029571128884451814651829189911296693586560466229864",
  // fyUSDC uses USDC_CCTP as underlying
  USDC_CCTP: "1442471627432665843583957153937277124821302887621015682060980008275741980155",
};

const VAULTS = {
  fyETH: "2273985559333219724429290159602994127325561082984750994597522992026660496918",
  fyUSDC: "3614629205322087119066064540472892217795595114760929205615786401399069436865",
};

const CONTRACTS = {
  VAULT_ALLOCATOR: "3148260697098218922501559176188655100084124891713026095862682167186975521235",
  AVNU_ROUTER: "3357347207369430956573753970315372111359878978740136719808196559187186094847",
  VESU_POOL: "1326796927197022071246993880086420967181713746138493709882850328569146018479",
  EKUBO_ADAPTER: "2516568162210255095453483626839089014569257854319119258892841327983140950402",
  STARKGATE_MIDDLEWARE: "2481085077367507779430085564211470162232307088275067678916369282054874743299",
  HYPERLANE_MIDDLEWARE: "2481085077367507779430085564211470162232307088275067678916369282054874743300",
  CCTP_MIDDLEWARE: "2481085077367507779430085564211470162232307088275067678916369282054874743301",
};

// L1/Cross-chain addresses
const L1_RECIPIENT = "917551056842671309452305380979543736893630245704";
const L1_USDC = "657322120784522198527611271132108531893007429161";
const CROSS_CHAIN_RECIPIENT = "0x732357e321Bf7a02CbB690fc2a629161D7722e29";

async function testAllOperations() {
  console.log("=== Comprehensive VaultCuratorSDK Example ===\n");

  // Load the SDK
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // ============================================
  // 1. BRING LIQUIDITY
  // ============================================
  console.log("1. BRING LIQUIDITY");
  const bringLiquidityOp = sdk.bringLiquidity({
    amount: "1000000", // 1 USDC
  });
  console.log("   Created bring liquidity operation");

  // ============================================
  // 2. ERC4626 OPERATIONS
  // ============================================
  console.log("\n2. ERC4626 OPERATIONS (fyETH vault)");

  const erc4626Ops = [
    sdk.approve({
      target: TOKENS.ETH,
      spender: VAULTS.fyETH,
      amount: "1000000000000000000",
    }),
    sdk.deposit({
      target: VAULTS.fyETH,
      assets: "1000000000000000000",
      receiver: CONTRACTS.VAULT_ALLOCATOR,
    }),
    sdk.mint({
      target: VAULTS.fyETH,
      shares: "500000000000000000",
      receiver: CONTRACTS.VAULT_ALLOCATOR,
    }),
    sdk.withdraw({
      target: VAULTS.fyETH,
      assets: "500000000000000000",
      receiver: CONTRACTS.VAULT_ALLOCATOR,
      owner: CONTRACTS.VAULT_ALLOCATOR,
    }),
    sdk.redeem({
      target: VAULTS.fyETH,
      shares: "250000000000000000",
      receiver: CONTRACTS.VAULT_ALLOCATOR,
      owner: CONTRACTS.VAULT_ALLOCATOR,
    }),
  ];
  console.log("   Created", erc4626Ops.length, "ERC4626 operations");

  // ============================================
  // 3. SVK STRATEGIES (Async Redemption)
  // ============================================
  console.log("\n3. SVK STRATEGIES (fyUSDC vault with async redemption)");

  const svkOps = [
    sdk.approve({
      target: TOKENS.USDC_CCTP, // fyUSDC uses USDC_CCTP as underlying
      spender: VAULTS.fyUSDC,
      amount: "1000000",
    }),
    sdk.deposit({
      target: VAULTS.fyUSDC,
      assets: "1000000",
      receiver: CONTRACTS.VAULT_ALLOCATOR,
    }),
    sdk.requestRedeem({
      target: VAULTS.fyUSDC,
      shares: "500000",
      receiver: CONTRACTS.VAULT_ALLOCATOR,
      owner: CONTRACTS.VAULT_ALLOCATOR,
    }),
    sdk.claimRedeem({
      target: VAULTS.fyUSDC,
      id: "1",
    }),
  ];
  console.log("   Created", svkOps.length, "SVK operations");

  // ============================================
  // 4. VESU V2 LENDING
  // ============================================
  console.log("\n4. VESU V2 LENDING");

  const vesuOps = [
    sdk.approve({
      target: TOKENS.WBTC,
      spender: CONTRACTS.VESU_POOL,
      amount: "100000000",
    }),
    sdk.modifyPositionV2({
      target: CONTRACTS.VESU_POOL,
      collateral_asset: TOKENS.WBTC,
      debt_asset: TOKENS.USDC,
      user: CONTRACTS.VAULT_ALLOCATOR,
      collateral: {
        denomination: "Native",
        value: { abs: "100000000", is_negative: false },
      },
      debt: {
        denomination: "Native",
        value: { abs: "50000000", is_negative: false },
      },
    }),
  ];
  console.log("   Created", vesuOps.length, "Vesu V2 operations");

  // ============================================
  // 5. EKUBO LP
  // ============================================
  console.log("\n5. EKUBO LP OPERATIONS");

  const ekuboOps = [
    sdk.approve({
      target: TOKENS.WBTC,
      spender: CONTRACTS.EKUBO_ADAPTER,
      amount: "10000000",
    }),
    sdk.approve({
      target: TOKENS.SolvBTC,
      spender: CONTRACTS.EKUBO_ADAPTER,
      amount: "10000000",
    }),
    sdk.ekuboDepositLiquidity({
      target: CONTRACTS.EKUBO_ADAPTER,
      amount0: "10000000",
      amount1: "10000000",
    }),
    sdk.ekuboWithdrawLiquidity({
      target: CONTRACTS.EKUBO_ADAPTER,
      ratioWad: "500000000000000000", // 50%
      minToken0: "0",
      minToken1: "0",
    }),
    sdk.ekuboCollectFees({
      target: CONTRACTS.EKUBO_ADAPTER,
    }),
  ];
  console.log("   Created", ekuboOps.length, "Ekubo operations");

  // ============================================
  // 6. AVNU SWAPS
  // ============================================
  console.log("\n6. AVNU SWAP OPERATIONS");

  const avnuOps = [
    sdk.approve({
      target: TOKENS.ETH,
      spender: CONTRACTS.AVNU_ROUTER,
      amount: "1000000000000000000",
    }),
    sdk.multiRouteSwap({
      target: CONTRACTS.AVNU_ROUTER,
      sell_token_address: TOKENS.ETH,
      sell_token_amount: "1000000000000000000",
      buy_token_address: TOKENS.USDC,
      buy_token_amount: "3000000000",
      buy_token_min_amount: "2900000000",
      beneficiary: CONTRACTS.VAULT_ALLOCATOR,
      integrator_fee_amount_bps: "0",
      integrator_fee_recipient: "0",
      routes: [
        {
          sell_token: TOKENS.ETH,
          buy_token: TOKENS.USDC,
          exchange_address: "0x123",
          percent: "100",
          additional_swap_params: [],
        },
      ],
    }),
  ];
  console.log("   Created", avnuOps.length, "AVNU operations");

  // ============================================
  // 7. STARKGATE BRIDGE
  // ============================================
  console.log("\n7. STARKGATE BRIDGE");

  const starkgateOps = [
    sdk.approve({
      target: TOKENS.USDC,
      spender: CONTRACTS.STARKGATE_MIDDLEWARE,
      amount: "1000000",
    }),
    sdk.bridgeTokenStarkgate({
      l1_token: L1_USDC,
      l1_recipient: L1_RECIPIENT,
      amount: "1000000",
    }),
  ];
  console.log("   Created", starkgateOps.length, "Starkgate operations");

  // ============================================
  // 8. HYPERLANE BRIDGE
  // ============================================
  console.log("\n8. HYPERLANE BRIDGE");

  const hyperlaneOps = [
    sdk.approve({
      target: TOKENS.USDC,
      spender: CONTRACTS.HYPERLANE_MIDDLEWARE,
      amount: "1000000",
    }),
    sdk.approve({
      target: TOKENS.STRK,
      spender: CONTRACTS.HYPERLANE_MIDDLEWARE,
      amount: "100000000000000000",
    }),
    sdk.bridgeTokenHyperlaneMiddleware({
      source_token: TOKENS.USDC,
      destination_token: TOKENS.USDC,
      amount: "1000000",
      destination_domain: "1",
      recipient: CROSS_CHAIN_RECIPIENT,
      strk_fee: "100000000000000000",
    }),
  ];
  console.log("   Created", hyperlaneOps.length, "Hyperlane operations");

  // ============================================
  // 9. CCTP BRIDGE
  // ============================================
  console.log("\n9. CCTP BRIDGE");

  const cctpOps = [
    sdk.approve({
      target: TOKENS.USDC_CCTP,
      spender: CONTRACTS.CCTP_MIDDLEWARE,
      amount: "1000000",
    }),
    sdk.bridgeTokenCctpMiddleware({
      burn_token: TOKENS.USDC_CCTP,
      token_to_claim: TOKENS.USDC,
      amount: "1000000",
      destination_domain: "0",
      mint_recipient: CROSS_CHAIN_RECIPIENT,
      destination_caller: "0",
      max_fee: "10000",
      min_finality_threshold: "1",
    }),
  ];
  console.log("   Created", cctpOps.length, "CCTP operations");

  // ============================================
  // 10. BUILD COMBINED CALLS
  // ============================================
  console.log("\n10. BUILDING COMBINED CALLS");

  // Example: Investment strategy
  const investmentStrategyOps = [
    // Bring liquidity to the vault
    sdk.bringLiquidity({ amount: "10000000" }),
    // Deposit into fyUSDC (uses USDC_CCTP as underlying)
    sdk.approve({
      target: TOKENS.USDC_CCTP,
      spender: VAULTS.fyUSDC,
      amount: "5000000",
    }),
    sdk.deposit({
      target: VAULTS.fyUSDC,
      assets: "5000000",
      receiver: CONTRACTS.VAULT_ALLOCATOR,
    }),
    // Add collateral to Vesu
    sdk.approve({
      target: TOKENS.WBTC,
      spender: CONTRACTS.VESU_POOL,
      amount: "50000000",
    }),
    sdk.modifyPositionV2({
      target: CONTRACTS.VESU_POOL,
      collateral_asset: TOKENS.WBTC,
      debt_asset: TOKENS.USDC,
      user: CONTRACTS.VAULT_ALLOCATOR,
      collateral: {
        denomination: "Native",
        value: { abs: "50000000", is_negative: false },
      },
      debt: {
        denomination: "Native",
        value: { abs: "0", is_negative: false },
      },
    }),
  ];

  const investmentCall = sdk.buildCall(investmentStrategyOps);
  console.log("   Investment strategy call:", {
    contractAddress: investmentCall.contractAddress,
    entrypoint: investmentCall.entrypoint,
    operationCount: investmentStrategyOps.length,
    calldataLength: (investmentCall.calldata as string[]).length,
  });

  // Example: Rebalancing strategy
  const rebalanceOps = [
    // Withdraw from Ekubo
    sdk.ekuboWithdrawLiquidity({
      target: CONTRACTS.EKUBO_ADAPTER,
      ratioWad: "1000000000000000000", // 100%
      minToken0: "0",
      minToken1: "0",
    }),
    sdk.ekuboCollectFees({
      target: CONTRACTS.EKUBO_ADAPTER,
    }),
    // Swap rewards
    sdk.approve({
      target: TOKENS.STRK,
      spender: CONTRACTS.AVNU_ROUTER,
      amount: "1000000000000000000",
    }),
    sdk.multiRouteSwap({
      target: CONTRACTS.AVNU_ROUTER,
      sell_token_address: TOKENS.STRK,
      sell_token_amount: "1000000000000000000",
      buy_token_address: TOKENS.USDC,
      buy_token_amount: "500000",
      buy_token_min_amount: "480000",
      beneficiary: CONTRACTS.VAULT_ALLOCATOR,
      integrator_fee_amount_bps: "0",
      integrator_fee_recipient: "0",
      routes: [
        {
          sell_token: TOKENS.STRK,
          buy_token: TOKENS.USDC,
          exchange_address: "0x456",
          percent: "100",
          additional_swap_params: [],
        },
      ],
    }),
  ];

  const rebalanceCall = sdk.buildCall(rebalanceOps);
  console.log("   Rebalance strategy call:", {
    operationCount: rebalanceOps.length,
    calldataLength: (rebalanceCall.calldata as string[]).length,
  });

  // ============================================
  // SUMMARY
  // ============================================
  console.log("\n=== SUMMARY ===");
  console.log("Available integrations:");
  console.log("  - ERC4626: deposit, mint, withdraw, redeem");
  console.log("  - SVK: requestRedeem, claimRedeem (async redemption)");
  console.log("  - Vesu V2: modifyPositionV2 (lending/borrowing)");
  console.log("  - Ekubo: depositLiquidity, withdrawLiquidity, collectFees, harvest");
  console.log("  - AVNU: multiRouteSwap (DEX aggregator)");
  console.log("  - Starkgate: bridgeTokenStarkgate, claimTokenStarkgate");
  console.log("  - Hyperlane: bridgeTokenHyperlaneMiddleware, claimTokenHyperlaneMiddleware");
  console.log("  - CCTP: bridgeTokenCctpMiddleware, claimTokenCctpMiddleware");
  console.log("\nAll operations return MerkleOperation objects.");
  console.log("Use buildCall() to combine multiple operations into a single transaction.");
}

testAllOperations().catch(console.error);

export { testAllOperations };
