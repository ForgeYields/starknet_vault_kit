/**
 * Example: ERC4626 Operations with VaultCuratorSDK
 * Demonstrates deposit, mint, withdraw, and redeem operations on ERC4626 vaults
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (from test.json)
const TOKENS = {
  ETH: "2087021424722619777119509474943472645767659996348769578120564519014510906823",
  fyETH:
    "2273985559333219724429290159602994127325561082984750994597522992026660496918",
  USDC: "2368576823837625528275935341135881659748932889268308403712618244410713532584",
  fyUSDC:
    "3614629205322087119066064540472892217795595114760929205615786401399069436865",
};

const VAULT_ALLOCATOR =
  "3148260697098218922501559176188655100084124891713026095862682167186975521235";

async function testERC4626Operations() {
  console.log("=== ERC4626 Operations Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const depositAmount = "1000000000000000000"; // 1 ETH (18 decimals)
  const mintShares = "500000000000000000"; // 0.5 shares
  const withdrawAmount = "500000000000000000"; // 0.5 ETH
  const redeemShares = "250000000000000000"; // 0.25 shares

  // ============================================
  // 1. Approve + Deposit into fyETH vault
  // ============================================
  console.log("1. Approve ETH for fyETH vault + Deposit");

  const approveForDeposit = sdk.approve({
    target: TOKENS.ETH,
    spender: TOKENS.fyETH,
    amount: depositAmount,
  });
  console.log("   Approve operation created:", {
    target: approveForDeposit.target,
    selector: approveForDeposit.selector,
  });

  const depositOp = sdk.deposit({
    target: TOKENS.fyETH,
    assets: depositAmount,
    receiver: VAULT_ALLOCATOR,
  });
  console.log("   Deposit operation created:", {
    target: depositOp.target,
    selector: depositOp.selector,
  });

  // Build the combined call
  const depositCall = sdk.buildCall([approveForDeposit, depositOp]);
  console.log("   Combined call:", {
    contractAddress: depositCall.contractAddress,
    entrypoint: depositCall.entrypoint,
    calldataLength: (depositCall.calldata as string[]).length,
  });

  // ============================================
  // 2. Mint shares from fyETH vault
  // ============================================
  console.log("\n2. Mint shares from fyETH vault");

  const mintOp = sdk.mint({
    target: TOKENS.fyETH,
    shares: mintShares,
    receiver: VAULT_ALLOCATOR,
  });
  console.log("   Mint operation created:", {
    target: mintOp.target,
    selector: mintOp.selector,
  });

  const mintCall = sdk.buildCall([mintOp]);
  console.log("   Mint call:", {
    contractAddress: mintCall.contractAddress,
    entrypoint: mintCall.entrypoint,
  });

  // ============================================
  // 3. Withdraw from fyETH vault
  // ============================================
  console.log("\n3. Withdraw from fyETH vault");

  const withdrawOp = sdk.withdraw({
    target: TOKENS.fyETH,
    assets: withdrawAmount,
    receiver: VAULT_ALLOCATOR,
    owner: VAULT_ALLOCATOR,
  });
  console.log("   Withdraw operation created:", {
    target: withdrawOp.target,
    selector: withdrawOp.selector,
  });

  const withdrawCall = sdk.buildCall([withdrawOp]);
  console.log("   Withdraw call:", {
    contractAddress: withdrawCall.contractAddress,
    entrypoint: withdrawCall.entrypoint,
  });

  // ============================================
  // 4. Redeem shares from fyETH vault
  // ============================================
  console.log("\n4. Redeem shares from fyETH vault");

  const redeemOp = sdk.redeem({
    target: TOKENS.fyETH,
    shares: redeemShares,
    receiver: VAULT_ALLOCATOR,
    owner: VAULT_ALLOCATOR,
  });
  console.log("   Redeem operation created:", {
    target: redeemOp.target,
    selector: redeemOp.selector,
  });

  const redeemCall = sdk.buildCall([redeemOp]);
  console.log("   Redeem call:", {
    contractAddress: redeemCall.contractAddress,
    entrypoint: redeemCall.entrypoint,
  });

  // ============================================
  // 5. Full cycle: Approve + Deposit + Withdraw in one transaction
  // ============================================
  console.log("\n5. Full cycle: Approve + Deposit + Withdraw");

  const fullCycleOps = [
    sdk.approve({
      target: TOKENS.ETH,
      spender: TOKENS.fyETH,
      amount: depositAmount,
    }),
    sdk.deposit({
      target: TOKENS.fyETH,
      assets: depositAmount,
      receiver: VAULT_ALLOCATOR,
    }),
    sdk.withdraw({
      target: TOKENS.fyETH,
      assets: withdrawAmount,
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

  console.log("\n=== ERC4626 Example Complete ===");
}

testERC4626Operations().catch(console.error);

export { testERC4626Operations };
