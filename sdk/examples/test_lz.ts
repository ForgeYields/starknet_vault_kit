/**
 * Example: LayerZero Bridge Operations with VaultCuratorSDK
 * Demonstrates cross-chain token bridging via LayerZero OFT
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (decimal format to match test.json)
const TOKENS = {
  WBTC: "1806018566677800621296032626439935115720767031724401394291089442012247156652",
  USDC: "2368576823837625528275935341135881659748932889268308403712618244410713532584",
  STRK: "2009894490435840142178314390393166646092438090257831307886760648929397478285",
};

// LayerZero WBTC OFT Adapter contract (decimal format)
const LZ_WBTC_OFT_ADAPTER =
  "2987327108307389660628511300677478412428831578776543507146742552736034022137";

// LayerZero middleware address (decimal format)
const LZ_MIDDLEWARE =
  "2481085077367507779430085564211470162232307088275067678916369282054874743303";

// Destination endpoint ID (e.g., Ethereum mainnet = 30101)
const ETH_EID = "30101";

// Recipient address on destination chain (as u256 hex string)
// Example: 0x732357e321Bf7a02CbB690fc2a629161D7722e29
const RECIPIENT = "0x732357e321Bf7a02CbB690fc2a629161D7722e29";

async function testLZDirectOFT() {
  console.log("=== LayerZero Direct OFT Bridge Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const bridgeAmount = "10000000"; // 0.1 WBTC (8 decimals)
  const minAmount = "9900000"; // 0.099 WBTC minimum (1% slippage)
  const nativeFee = "100000000000000000"; // 0.1 STRK fee

  // ============================================
  // 1. Approve tokens for OFT adapter contract
  // ============================================
  console.log("1. Approve WBTC and STRK for OFT Adapter contract");
  console.log("   Note: STRK is used to pay for cross-chain message fees");

  const approveWBTC = sdk.approve({
    target: TOKENS.WBTC,
    spender: LZ_WBTC_OFT_ADAPTER,
    amount: bridgeAmount,
  });
  console.log("   Approve WBTC:", { target: approveWBTC.target });

  const approveSTRK = sdk.approve({
    target: TOKENS.STRK,
    spender: LZ_WBTC_OFT_ADAPTER,
    amount: nativeFee,
  });
  console.log("   Approve STRK (for fees):", { target: approveSTRK.target });

  // ============================================
  // 2. Bridge WBTC to Ethereum via LayerZero
  // ============================================
  console.log("\n2. Bridge WBTC to Ethereum via LayerZero OFT Adapter");
  console.log("   Destination EID:", ETH_EID, "(Ethereum)");
  console.log("   Recipient:", RECIPIENT);

  try {
    const bridgeOp = sdk.bridgeLZ({
      oft: LZ_WBTC_OFT_ADAPTER,
      dst_eid: ETH_EID,
      to: RECIPIENT,
      amount: bridgeAmount,
      min_amount: minAmount,
      native_fee: nativeFee,
    });
    console.log("   Bridge operation:", {
      target: bridgeOp.target,
      selector: bridgeOp.selector,
    });
  } catch (e) {
    console.log("   Error:", (e as Error).message);
  }

  console.log("\n=== Direct OFT Example Complete ===");
}

async function testLZMiddleware() {
  console.log("\n=== LayerZero Middleware Bridge Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const bridgeAmount = "10000000"; // 0.1 WBTC (8 decimals)
  const minAmount = "9900000"; // 0.099 WBTC minimum
  const nativeFee = "100000000000000000"; // 0.1 STRK fee

  // ============================================
  // 1. Approve tokens for middleware
  // ============================================
  console.log("1. Approve WBTC (underlying) and STRK for middleware");

  const approveWBTC = sdk.approve({
    target: TOKENS.WBTC,
    spender: LZ_MIDDLEWARE,
    amount: bridgeAmount,
  });
  console.log("   Approve WBTC:", { target: approveWBTC.target });

  const approveSTRK = sdk.approve({
    target: TOKENS.STRK,
    spender: LZ_MIDDLEWARE,
    amount: nativeFee,
  });
  console.log("   Approve STRK (for fees):", { target: approveSTRK.target });

  // ============================================
  // 2. Bridge via middleware (for adapter OFT)
  // ============================================
  console.log("\n2. Bridge via LZ Middleware");
  console.log("   OFT contract:", LZ_WBTC_OFT_ADAPTER);
  console.log("   Underlying token:", TOKENS.WBTC);
  console.log("   Token to claim:", TOKENS.USDC);
  console.log("   Destination EID:", ETH_EID);
  console.log("   Recipient:", RECIPIENT);

  try {
    const bridgeOp = sdk.bridgeLZMiddleware({
      oft: LZ_WBTC_OFT_ADAPTER,
      underlying_token: TOKENS.WBTC,
      token_to_claim: TOKENS.USDC, // Token to receive back (e.g., swap to USDC on dest)
      dst_eid: ETH_EID,
      to: RECIPIENT,
      amount: bridgeAmount,
      min_amount: minAmount,
      native_fee: nativeFee,
    });
    console.log("   Bridge operation:", {
      target: bridgeOp.target,
      selector: bridgeOp.selector,
    });

    // Build full call with approvals
    const fullCall = sdk.buildCall([approveWBTC, approveSTRK, bridgeOp]);
    console.log("   Full call:", {
      contractAddress: fullCall.contractAddress,
      entrypoint: fullCall.entrypoint,
    });
  } catch (e) {
    console.log("   Error:", (e as Error).message);
  }

  console.log("\n=== LayerZero Middleware Example Complete ===");
  console.log("\nNotes:");
  console.log("- LayerZero enables cross-chain token transfers via OFT standard");
  console.log("- STRK is used to pay for cross-chain messaging fees (native_fee)");
  console.log("- dst_eid identifies the destination chain endpoint");
  console.log("- For adapter OFT: underlying_token != oft (approval needed)");
  console.log("- For native OFT: underlying_token == oft");
  console.log("- claim_token is PERMISSIONLESS - call directly on middleware contract");
}

async function main() {
  await testLZDirectOFT();
  await testLZMiddleware();
}

main().catch(console.error);

export { testLZDirectOFT, testLZMiddleware };
