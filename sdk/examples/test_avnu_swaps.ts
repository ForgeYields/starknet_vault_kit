/**
 * Example: AVNU Swap Operations with VaultCuratorSDK
 * Demonstrates multi-route swaps with the AVNU aggregator
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (from test.json)
const TOKENS = {
  ETH: "2087021424722619777119509474943472645767659996348769578120564519014510906823",
  USDC: "2368576823837625528275935341135881659748932889268308403712618244410713532584",
  STRK: "2009894490435840142178314390393166646092438090257831307886760648929397478285",
};

const AVNU_ROUTER =
  "3357347207369430956573753970315372111359878978740136719808196559187186094847";

const VAULT_ALLOCATOR =
  "3148260697098218922501559176188655100084124891713026095862682167186975521235";

async function testAvnuSwaps() {
  console.log("=== AVNU Swap Operations Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const ethAmount = "1000000000000000000"; // 1 ETH (18 decimals)
  const strkAmount = "100000000000000000000"; // 100 STRK (18 decimals)
  const usdcAmount = "1000000"; // 1 USDC (6 decimals)

  // ============================================
  // 1. Approve ETH for AVNU router
  // ============================================
  console.log("1. Approve ETH for AVNU router");

  const approveETH = sdk.approve({
    target: TOKENS.ETH,
    spender: AVNU_ROUTER,
    amount: ethAmount,
  });
  console.log("   Approve operation:", { target: approveETH.target });

  // ============================================
  // 2. Swap ETH -> USDC (single route)
  // ============================================
  console.log("\n2. Swap ETH -> USDC");

  const ethToUsdcSwap = sdk.multiRouteSwap({
    target: AVNU_ROUTER,
    sell_token_address: TOKENS.ETH,
    sell_token_amount: ethAmount,
    buy_token_address: TOKENS.USDC,
    buy_token_amount: "3000000000", // Expected ~3000 USDC
    buy_token_min_amount: "2900000000", // Min 2900 USDC (slippage protection)
    beneficiary: VAULT_ALLOCATOR,
    integrator_fee_amount_bps: "0",
    integrator_fee_recipient: "0",
    routes: [
      {
        sell_token: TOKENS.ETH,
        buy_token: TOKENS.USDC,
        exchange_address: "0x123", // Actual DEX address from AVNU API
        percent: "100", // 100% through this route
        additional_swap_params: [],
      },
    ],
  });
  console.log("   ETH -> USDC swap:", {
    target: ethToUsdcSwap.target,
    selector: ethToUsdcSwap.selector,
  });

  const ethToUsdcCall = sdk.buildCall([approveETH, ethToUsdcSwap]);
  console.log("   Combined call built with", (ethToUsdcCall.calldata as string[]).length, "elements");

  // ============================================
  // 3. Swap USDC -> ETH (reverse)
  // ============================================
  console.log("\n3. Swap USDC -> ETH");

  const approveUSDC = sdk.approve({
    target: TOKENS.USDC,
    spender: AVNU_ROUTER,
    amount: usdcAmount,
  });

  const usdcToEthSwap = sdk.multiRouteSwap({
    target: AVNU_ROUTER,
    sell_token_address: TOKENS.USDC,
    sell_token_amount: usdcAmount,
    buy_token_address: TOKENS.ETH,
    buy_token_amount: "300000000000000", // Expected ~0.0003 ETH
    buy_token_min_amount: "290000000000000", // Min with slippage
    beneficiary: VAULT_ALLOCATOR,
    integrator_fee_amount_bps: "0",
    integrator_fee_recipient: "0",
    routes: [
      {
        sell_token: TOKENS.USDC,
        buy_token: TOKENS.ETH,
        exchange_address: "0x123",
        percent: "100",
        additional_swap_params: [],
      },
    ],
  });
  console.log("   USDC -> ETH swap:", {
    target: usdcToEthSwap.target,
  });

  const usdcToEthCall = sdk.buildCall([approveUSDC, usdcToEthSwap]);
  console.log("   Reverse swap call built");

  // ============================================
  // 4. Swap STRK -> USDC
  // ============================================
  console.log("\n4. Swap STRK -> USDC");

  const approveSTRK = sdk.approve({
    target: TOKENS.STRK,
    spender: AVNU_ROUTER,
    amount: strkAmount,
  });

  const strkToUsdcSwap = sdk.multiRouteSwap({
    target: AVNU_ROUTER,
    sell_token_address: TOKENS.STRK,
    sell_token_amount: strkAmount,
    buy_token_address: TOKENS.USDC,
    buy_token_amount: "50000000", // Expected ~50 USDC
    buy_token_min_amount: "48000000", // Min 48 USDC
    beneficiary: VAULT_ALLOCATOR,
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
  });
  console.log("   STRK -> USDC swap:", {
    target: strkToUsdcSwap.target,
  });

  const strkToUsdcCall = sdk.buildCall([approveSTRK, strkToUsdcSwap]);
  console.log("   STRK swap call built");

  // ============================================
  // 5. Swap USDC -> STRK (reverse)
  // ============================================
  console.log("\n5. Swap USDC -> STRK");

  const usdcToStrkSwap = sdk.multiRouteSwap({
    target: AVNU_ROUTER,
    sell_token_address: TOKENS.USDC,
    sell_token_amount: usdcAmount,
    buy_token_address: TOKENS.STRK,
    buy_token_amount: "2000000000000000000", // Expected ~2 STRK
    buy_token_min_amount: "1900000000000000000", // Min with slippage
    beneficiary: VAULT_ALLOCATOR,
    integrator_fee_amount_bps: "0",
    integrator_fee_recipient: "0",
    routes: [
      {
        sell_token: TOKENS.USDC,
        buy_token: TOKENS.STRK,
        exchange_address: "0x456",
        percent: "100",
        additional_swap_params: [],
      },
    ],
  });
  console.log("   USDC -> STRK swap:", {
    target: usdcToStrkSwap.target,
  });

  // ============================================
  // 6. Multi-route swap (split across DEXes)
  // ============================================
  console.log("\n6. Multi-route swap (split across DEXes)");

  const multiRouteSwap = sdk.multiRouteSwap({
    target: AVNU_ROUTER,
    sell_token_address: TOKENS.ETH,
    sell_token_amount: ethAmount,
    buy_token_address: TOKENS.USDC,
    buy_token_amount: "3000000000",
    buy_token_min_amount: "2900000000",
    beneficiary: VAULT_ALLOCATOR,
    integrator_fee_amount_bps: "0",
    integrator_fee_recipient: "0",
    routes: [
      {
        sell_token: TOKENS.ETH,
        buy_token: TOKENS.USDC,
        exchange_address: "0x111", // JediSwap
        percent: "50", // 50% through JediSwap
        additional_swap_params: [],
      },
      {
        sell_token: TOKENS.ETH,
        buy_token: TOKENS.USDC,
        exchange_address: "0x222", // MySwap
        percent: "30", // 30% through MySwap
        additional_swap_params: [],
      },
      {
        sell_token: TOKENS.ETH,
        buy_token: TOKENS.USDC,
        exchange_address: "0x333", // Ekubo
        percent: "20", // 20% through Ekubo
        additional_swap_params: [],
      },
    ],
  });
  console.log("   Multi-route swap:", {
    target: multiRouteSwap.target,
    routeCount: 3,
  });

  // ============================================
  // 7. Full trading session
  // ============================================
  console.log("\n7. Full trading session: Multiple swaps");

  const tradingSessionOps = [
    sdk.approve({
      target: TOKENS.ETH,
      spender: AVNU_ROUTER,
      amount: ethAmount,
    }),
    sdk.multiRouteSwap({
      target: AVNU_ROUTER,
      sell_token_address: TOKENS.ETH,
      sell_token_amount: ethAmount,
      buy_token_address: TOKENS.USDC,
      buy_token_amount: "3000000000",
      buy_token_min_amount: "2900000000",
      beneficiary: VAULT_ALLOCATOR,
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
    sdk.approve({
      target: TOKENS.USDC,
      spender: AVNU_ROUTER,
      amount: "1500000000", // 1500 USDC
    }),
    sdk.multiRouteSwap({
      target: AVNU_ROUTER,
      sell_token_address: TOKENS.USDC,
      sell_token_amount: "1500000000",
      buy_token_address: TOKENS.STRK,
      buy_token_amount: "3000000000000000000000",
      buy_token_min_amount: "2900000000000000000000",
      beneficiary: VAULT_ALLOCATOR,
      integrator_fee_amount_bps: "0",
      integrator_fee_recipient: "0",
      routes: [
        {
          sell_token: TOKENS.USDC,
          buy_token: TOKENS.STRK,
          exchange_address: "0x456",
          percent: "100",
          additional_swap_params: [],
        },
      ],
    }),
  ];

  const tradingSessionCall = sdk.buildCall(tradingSessionOps);
  console.log("   Trading session call:", {
    contractAddress: tradingSessionCall.contractAddress,
    entrypoint: tradingSessionCall.entrypoint,
    operationCount: tradingSessionOps.length,
    calldataLength: (tradingSessionCall.calldata as string[]).length,
  });

  console.log("\n=== AVNU Swap Example Complete ===");
  console.log("\nNotes:");
  console.log("- Always approve tokens before swapping");
  console.log("- buy_token_min_amount provides slippage protection");
  console.log("- Routes can be split across multiple DEXes for better execution");
  console.log("- Get actual routes from AVNU API for production use");
}

testAvnuSwaps().catch(console.error);

export { testAvnuSwaps };
