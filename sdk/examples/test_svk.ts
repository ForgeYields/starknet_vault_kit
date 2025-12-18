/**
 * Example: Starknet Vault Kit (SVK) Strategy Operations
 * Demonstrates async redemption with request_redeem and claim_redeem
 * SVK strategies use ERC7540 async redemption pattern
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (from test.json)
// Note: fyUSDC vault uses USDC_CCTP as underlying, not regular USDC
const TOKENS = {
  USDC_CCTP:
    "1442471627432665843583957153937277124821302887621015682060980008275741980155",
  fyUSDC:
    "3614629205322087119066064540472892217795595114760929205615786401399069436865",
};

const VAULT_ALLOCATOR =
  "3148260697098218922501559176188655100084124891713026095862682167186975521235";

async function testSVKOperations() {
  console.log("=== Starknet Vault Kit Strategy Operations ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const depositAmount = "1000000"; // 1 USDC (6 decimals)
  const mintShares = "500000"; // 0.5 shares
  const redeemShares = "250000"; // 0.25 shares
  const claimId = "1"; // NFT ID for claim

  // ============================================
  // 1. Approve + Deposit into fyUSDC vault
  // ============================================
  console.log("1. Approve USDC for fyUSDC vault + Deposit");

  const approveForDeposit = sdk.approve({
    target: TOKENS.USDC_CCTP,
    spender: TOKENS.fyUSDC,
    amount: depositAmount,
  });
  console.log("   Approve operation:", {
    target: approveForDeposit.target,
  });

  const depositOp = sdk.deposit({
    target: TOKENS.fyUSDC,
    assets: depositAmount,
    receiver: VAULT_ALLOCATOR,
  });
  console.log("   Deposit operation:", {
    target: depositOp.target,
  });

  const depositCall = sdk.buildCall([approveForDeposit, depositOp]);
  console.log("   Combined call built with", (depositCall.calldata as string[]).length, "calldata elements");

  // ============================================
  // 2. Mint shares from fyUSDC vault
  // ============================================
  console.log("\n2. Mint shares from fyUSDC vault");

  const mintOp = sdk.mint({
    target: TOKENS.fyUSDC,
    shares: mintShares,
    receiver: VAULT_ALLOCATOR,
  });
  console.log("   Mint operation:", {
    target: mintOp.target,
  });

  const mintCall = sdk.buildCall([mintOp]);
  console.log("   Mint call built");

  // ============================================
  // 3. Request Redeem (async redemption step 1)
  // ============================================
  console.log("\n3. Request Redeem (ERC7540 async redemption)");
  console.log("   Note: This creates an NFT representing the redemption request");

  const requestRedeemOp = sdk.requestRedeem({
    target: TOKENS.fyUSDC,
    shares: redeemShares,
    receiver: VAULT_ALLOCATOR,
    owner: VAULT_ALLOCATOR,
  });
  console.log("   Request redeem operation:", {
    target: requestRedeemOp.target,
    selector: requestRedeemOp.selector,
  });

  const requestRedeemCall = sdk.buildCall([requestRedeemOp]);
  console.log("   Request redeem call built");

  // ============================================
  // 4. Claim Redeem (async redemption step 2)
  // ============================================
  console.log("\n4. Claim Redeem (after epoch transition)");
  console.log("   Note: This burns the NFT and transfers the underlying assets");

  const claimRedeemOp = sdk.claimRedeem({
    target: TOKENS.fyUSDC,
    id: claimId,
  });
  console.log("   Claim redeem operation:", {
    target: claimRedeemOp.target,
    selector: claimRedeemOp.selector,
  });

  const claimRedeemCall = sdk.buildCall([claimRedeemOp]);
  console.log("   Claim redeem call built");

  // ============================================
  // 5. Full SVK investment cycle
  // ============================================
  console.log("\n5. Full SVK investment cycle");
  console.log("   Approve -> Deposit -> Mint -> RequestRedeem");

  const fullCycleOps = [
    sdk.approve({
      target: TOKENS.USDC_CCTP,
      spender: TOKENS.fyUSDC,
      amount: depositAmount,
    }),
    sdk.deposit({
      target: TOKENS.fyUSDC,
      assets: depositAmount,
      receiver: VAULT_ALLOCATOR,
    }),
    sdk.mint({
      target: TOKENS.fyUSDC,
      shares: mintShares,
      receiver: VAULT_ALLOCATOR,
    }),
    sdk.requestRedeem({
      target: TOKENS.fyUSDC,
      shares: redeemShares,
      receiver: VAULT_ALLOCATOR,
      owner: VAULT_ALLOCATOR,
    }),
  ];

  const fullCycleCall = sdk.buildCall(fullCycleOps);
  console.log("   Full cycle call:", {
    contractAddress: fullCycleCall.contractAddress,
    entrypoint: fullCycleCall.entrypoint,
    operationCount: fullCycleOps.length,
    calldataLength: (fullCycleCall.calldata as string[]).length,
  });

  console.log("\n=== SVK Strategy Example Complete ===");
  console.log("\nNotes:");
  console.log("- SVK strategies use ERC7540 async redemption pattern");
  console.log("- request_redeem creates an NFT that can be claimed after epoch transition");
  console.log("- claim_redeem burns the NFT and transfers the underlying assets");
}

testSVKOperations().catch(console.error);

export { testSVKOperations };
