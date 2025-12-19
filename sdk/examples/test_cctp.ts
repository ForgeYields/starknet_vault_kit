/**
 * Example: CCTP (Cross-Chain Transfer Protocol) Operations with VaultCuratorSDK
 * Demonstrates native USDC bridging via Circle's CCTP
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (from test.json)
const TOKENS = {
  USDC: "2368576823837625528275935341135881659748932889268308403712618244410713532584",
  // CCTP uses native USDC which may have a different address
  USDC_CCTP:
    "1442471627432665843583957153937277124821302887621015682060980008275741980155",
};

// CCTP middleware address
const CCTP_MIDDLEWARE =
  "2481085077367507779430085564211470162232307088275067678916369282054874743301";

// Destination domain (Ethereum = 0 for CCTP)
const ETHEREUM_CCTP_DOMAIN = "0";

// Recipient address on destination chain (as u256)
// 0x732357e321Bf7a02CbB690fc2a629161D7722e29
const MINT_RECIPIENT_LOW = "44858727236356512580505469151245119017";
const MINT_RECIPIENT_HIGH = "1931696099";
const MINT_RECIPIENT = "0x732357e321Bf7a02CbB690fc2a629161D7722e29";

// Destination caller (0 = no restriction)
const DESTINATION_CALLER = "0";

async function testCctpOperations() {
  console.log("=== CCTP Bridge Operations Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const bridgeAmount = "1000000"; // 1 USDC (6 decimals)
  const maxFee = "10000"; // Max fee in USDC
  const minFinalityThreshold = "1"; // Minimum finality blocks

  // ============================================
  // 1. Approve USDC for CCTP middleware
  // ============================================
  console.log("1. Approve USDC for CCTP middleware");

  const approveOp = sdk.approve({
    target: TOKENS.USDC_CCTP,
    spender: CCTP_MIDDLEWARE,
    amount: bridgeAmount,
  });
  console.log("   Approve operation:", {
    target: approveOp.target,
  });

  // ============================================
  // 2. Bridge USDC via CCTP (deposit_for_burn)
  // ============================================
  console.log("\n2. Bridge USDC to Ethereum via CCTP");
  console.log("   Destination domain:", ETHEREUM_CCTP_DOMAIN, "(Ethereum)");
  console.log("   Mint recipient:", MINT_RECIPIENT);

  const bridgeOp = sdk.bridgeTokenCctpMiddleware({
    burn_token: TOKENS.USDC_CCTP,
    token_to_claim: TOKENS.USDC,
    amount: bridgeAmount,
    destination_domain: ETHEREUM_CCTP_DOMAIN,
    mint_recipient: MINT_RECIPIENT,
    destination_caller: DESTINATION_CALLER,
    max_fee: maxFee,
    min_finality_threshold: minFinalityThreshold,
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
      target: TOKENS.USDC_CCTP,
      spender: CCTP_MIDDLEWARE,
      amount: bridgeAmount,
    }),
    sdk.bridgeTokenCctpMiddleware({
      burn_token: TOKENS.USDC_CCTP,
      token_to_claim: TOKENS.USDC,
      amount: bridgeAmount,
      destination_domain: ETHEREUM_CCTP_DOMAIN,
      mint_recipient: MINT_RECIPIENT,
      destination_caller: DESTINATION_CALLER,
      max_fee: maxFee,
      min_finality_threshold: minFinalityThreshold,
    }),
  ];

  const fullBridgeCall = sdk.buildCall(fullBridgeOps);
  console.log("   Full bridge call:", {
    contractAddress: fullBridgeCall.contractAddress,
    entrypoint: fullBridgeCall.entrypoint,
    operationCount: fullBridgeOps.length,
  });

  // ============================================
  // 4. Understanding CCTP parameters
  // ============================================
  console.log("\n4. CCTP Parameter Reference:");
  console.log("   - burn_token: The USDC token to burn on source chain");
  console.log("   - token_to_claim: The USDC token to receive on destination");
  console.log("   - destination_domain: 0=Ethereum, 1=Avalanche, etc.");
  console.log("   - mint_recipient: Address receiving USDC on destination");
  console.log("   - destination_caller: Restrict who can complete the transfer (0=anyone)");
  console.log("   - max_fee: Maximum fee willing to pay");
  console.log("   - min_finality_threshold: Blocks to wait for finality");

  console.log("\n=== CCTP Bridge Example Complete ===");
  console.log("\nNotes:");
  console.log("- CCTP is Circle's native USDC bridging protocol");
  console.log("- USDC is burned on source chain and minted on destination");
  console.log("- More secure than wrapped tokens (no bridge risk)");
  console.log("- Domain 0 = Ethereum for CCTP (different from Hyperlane)");
}

testCctpOperations().catch(console.error);

export { testCctpOperations };
