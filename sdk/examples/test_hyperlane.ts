/**
 * Example: Hyperlane Bridge Operations with VaultCuratorSDK
 * Demonstrates cross-chain token bridging via Hyperlane
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (from test.json)
const TOKENS = {
  USDC: "2368576823837625528275935341135881659748932889268308403712618244410713532584",
  STRK: "2009894490435840142178314390393166646092438090257831307886760648929397478285",
};

// Hyperlane middleware address
const HYPERLANE_MIDDLEWARE =
  "2481085077367507779430085564211470162232307088275067678916369282054874743300";

// Destination domain (Ethereum = 1)
const ETHEREUM_DOMAIN = "1";

// Recipient address on destination chain (as u256)
// 0x732357e321Bf7a02CbB690fc2a629161D7722e29
const RECIPIENT_LOW = "44858727236356512580505469151245119017"; // low 128 bits
const RECIPIENT_HIGH = "1931696099"; // high 128 bits
const RECIPIENT = "0x732357e321Bf7a02CbB690fc2a629161D7722e29";

async function testHyperlaneOperations() {
  console.log("=== Hyperlane Bridge Operations Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const bridgeAmount = "1000000"; // 1 USDC (6 decimals)
  const strkFee = "100000000000000000"; // 0.1 STRK fee

  // ============================================
  // 1. Approve tokens for Hyperlane middleware
  // ============================================
  console.log("1. Approve USDC and STRK for Hyperlane middleware");
  console.log("   Note: STRK is used to pay for cross-chain message fees");

  const approveUSDC = sdk.approve({
    target: TOKENS.USDC,
    spender: HYPERLANE_MIDDLEWARE,
    amount: bridgeAmount,
  });
  console.log("   Approve USDC:", { target: approveUSDC.target });

  const approveSTRK = sdk.approve({
    target: TOKENS.STRK,
    spender: HYPERLANE_MIDDLEWARE,
    amount: strkFee,
  });
  console.log("   Approve STRK (for fees):", { target: approveSTRK.target });

  // ============================================
  // 2. Bridge USDC to Ethereum via Hyperlane
  // ============================================
  console.log("\n2. Bridge USDC to Ethereum via Hyperlane");
  console.log("   Destination domain:", ETHEREUM_DOMAIN, "(Ethereum)");
  console.log("   Recipient:", RECIPIENT);

  const bridgeOp = sdk.bridgeTokenHyperlaneMiddleware({
    source_token: TOKENS.USDC,
    destination_token: TOKENS.USDC,
    amount: bridgeAmount,
    destination_domain: ETHEREUM_DOMAIN,
    recipient: RECIPIENT,
    strk_fee: strkFee,
  });
  console.log("   Bridge operation:", {
    target: bridgeOp.target,
    selector: bridgeOp.selector,
  });

  const bridgeCall = sdk.buildCall([approveUSDC, approveSTRK, bridgeOp]);
  console.log("   Combined call:", {
    contractAddress: bridgeCall.contractAddress,
    entrypoint: bridgeCall.entrypoint,
    calldataLength: (bridgeCall.calldata as string[]).length,
  });

  // ============================================
  // 3. Full bridge cycle
  // ============================================
  console.log("\n3. Full bridge cycle: Approve USDC + Approve STRK + Bridge");

  const fullBridgeOps = [
    sdk.approve({
      target: TOKENS.USDC,
      spender: HYPERLANE_MIDDLEWARE,
      amount: bridgeAmount,
    }),
    sdk.approve({
      target: TOKENS.STRK,
      spender: HYPERLANE_MIDDLEWARE,
      amount: strkFee,
    }),
    sdk.bridgeTokenHyperlaneMiddleware({
      source_token: TOKENS.USDC,
      destination_token: TOKENS.USDC,
      amount: bridgeAmount,
      destination_domain: ETHEREUM_DOMAIN,
      recipient: RECIPIENT,
      strk_fee: strkFee,
    }),
  ];

  const fullBridgeCall = sdk.buildCall(fullBridgeOps);
  console.log("   Full bridge call:", {
    contractAddress: fullBridgeCall.contractAddress,
    entrypoint: fullBridgeCall.entrypoint,
    operationCount: fullBridgeOps.length,
  });

  console.log("\n=== Hyperlane Bridge Example Complete ===");
  console.log("\nNotes:");
  console.log("- Hyperlane enables cross-chain token transfers");
  console.log("- STRK is used to pay for cross-chain messaging fees");
  console.log("- destination_domain identifies the target chain (1 = Ethereum)");
  console.log("- recipient is the address on the destination chain");
  console.log("- claim_token is used to receive tokens bridged to Starknet");
}

testHyperlaneOperations().catch(console.error);

export { testHyperlaneOperations };
