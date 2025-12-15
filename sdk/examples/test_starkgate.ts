/**
 * Example: Starkgate Bridge Operations with VaultCuratorSDK
 * Demonstrates bridging tokens from Starknet L2 to Ethereum L1
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (from test.json)
const TOKENS = {
  USDC: "2368576823837625528275935341135881659748932889268308403712618244410713532584",
};

// Starkgate middleware address
const STARKGATE_MIDDLEWARE =
  "2481085077367507779430085564211470162232307088275067678916369282054874743299";

// L2 Bridge address for USDC
const STARKGATE_USDC_BRIDGE =
  "2624271632322125921217374734393920890821192138210577916078337694621182820758";

// L1 recipient address (Ethereum)
const L1_RECIPIENT = "917551056842671309452305380979543736893630245704"; // 0x732357e321Bf7a02CbB690fc2a629161D7722e29

// L1 USDC token address
const L1_USDC = "657322120784522198527611271132108531893007429161"; // Ethereum USDC address

async function testStarkgateOperations() {
  console.log("=== Starkgate Bridge Operations Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amount
  const bridgeAmount = "1000000"; // 1 USDC (6 decimals)

  // ============================================
  // 1. Approve USDC for Starkgate middleware
  // ============================================
  console.log("1. Approve USDC for Starkgate middleware");

  const approveOp = sdk.approve({
    target: TOKENS.USDC,
    spender: STARKGATE_MIDDLEWARE,
    amount: bridgeAmount,
  });
  console.log("   Approve operation:", {
    target: approveOp.target,
  });

  // ============================================
  // 2. Bridge USDC to Ethereum via Starkgate
  // ============================================
  console.log("\n2. Bridge USDC to Ethereum");
  console.log("   L1 Recipient:", L1_RECIPIENT);

  const bridgeOp = sdk.bridgeTokenStarkgate({
    l1_token: L1_USDC,
    l1_recipient: L1_RECIPIENT,
    amount: bridgeAmount,
  });
  console.log("   Bridge operation:", {
    target: bridgeOp.target,
    selector: bridgeOp.selector,
  });

  const bridgeCall = sdk.buildCall([approveOp, bridgeOp]);
  console.log("   Combined call:", {
    contractAddress: bridgeCall.contractAddress,
    entrypoint: bridgeCall.entrypoint,
    calldataLength: (bridgeCall.calldata as string[]).length,
  });

  // ============================================
  // 3. Full bridge cycle
  // ============================================
  console.log("\n3. Full bridge cycle: Approve + Bridge");

  const fullBridgeOps = [
    sdk.approve({
      target: TOKENS.USDC,
      spender: STARKGATE_MIDDLEWARE,
      amount: bridgeAmount,
    }),
    sdk.bridgeTokenStarkgate({
      l1_token: L1_USDC,
      l1_recipient: L1_RECIPIENT,
      amount: bridgeAmount,
    }),
  ];

  const fullBridgeCall = sdk.buildCall(fullBridgeOps);
  console.log("   Full bridge call:", {
    contractAddress: fullBridgeCall.contractAddress,
    entrypoint: fullBridgeCall.entrypoint,
    operationCount: fullBridgeOps.length,
  });

  console.log("\n=== Starkgate Bridge Example Complete ===");
  console.log("\nNotes:");
  console.log("- Starkgate bridges tokens between Starknet L2 and Ethereum L1");
  console.log("- L1 withdrawals require waiting for L1 finality");
  console.log("- claim_token_bridged_back is for receiving tokens from L1");
  console.log("- The middleware handles the bridge contract interactions");
}

testStarkgateOperations().catch(console.error);

export { testStarkgateOperations };
