/**
 * Example: Ekubo LP Operations with VaultCuratorSDK
 * Demonstrates liquidity provision, withdrawal, fee collection, and harvesting
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (from test.json)
const TOKENS = {
  WBTC: "1806018566677800621296032626439935115720767031724401394291089442012247156652",
  SolvBTC:
    "2522838177878422711967992029571128884451814651829189911296693586560466229864",
  STRK: "2009894490435840142178314390393166646092438090257831307886760648929397478285",
};

// Ekubo adapter for WBTC/SolvBTC pair
const EKUBO_ADAPTER =
  "2516568162210255095453483626839089014569257854319119258892841327983140950402";

async function testEkuboOperations() {
  console.log("=== Ekubo LP Operations Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const wbtcAmount = "10000000"; // 0.1 WBTC (8 decimals)
  const solvBtcAmount = "10000000"; // 0.1 SolvBTC (8 decimals)
  const withdrawRatioWad = "500000000000000000"; // 50% (18 decimals, WAD format)

  // ============================================
  // 1. Approve tokens for Ekubo adapter
  // ============================================
  console.log("1. Approve WBTC and SolvBTC for Ekubo adapter");

  const approveWBTC = sdk.approve({
    target: TOKENS.WBTC,
    spender: EKUBO_ADAPTER,
    amount: wbtcAmount,
  });
  console.log("   Approve WBTC:", { target: approveWBTC.target });

  const approveSolvBTC = sdk.approve({
    target: TOKENS.SolvBTC,
    spender: EKUBO_ADAPTER,
    amount: solvBtcAmount,
  });
  console.log("   Approve SolvBTC:", { target: approveSolvBTC.target });

  // ============================================
  // 2. Deposit liquidity to Ekubo
  // ============================================
  console.log("\n2. Deposit liquidity to Ekubo pool");

  const depositLiquidityOp = sdk.ekuboDepositLiquidity({
    target: EKUBO_ADAPTER,
    amount0: wbtcAmount,
    amount1: solvBtcAmount,
  });
  console.log("   Deposit liquidity operation:", {
    target: depositLiquidityOp.target,
    selector: depositLiquidityOp.selector,
  });

  const depositLiquidityCall = sdk.buildCall([
    approveWBTC,
    approveSolvBTC,
    depositLiquidityOp,
  ]);
  console.log("   Combined call built with", (depositLiquidityCall.calldata as string[]).length, "elements");

  // ============================================
  // 3. Withdraw liquidity from Ekubo
  // ============================================
  console.log("\n3. Withdraw liquidity from Ekubo pool");

  const withdrawLiquidityOp = sdk.ekuboWithdrawLiquidity({
    target: EKUBO_ADAPTER,
    ratioWad: withdrawRatioWad, // 50% withdrawal
    minToken0: "0", // Minimum WBTC to receive
    minToken1: "0", // Minimum SolvBTC to receive
  });
  console.log("   Withdraw liquidity operation:", {
    target: withdrawLiquidityOp.target,
    selector: withdrawLiquidityOp.selector,
  });

  const withdrawCall = sdk.buildCall([withdrawLiquidityOp]);
  console.log("   Withdraw call built");

  // ============================================
  // 4. Collect trading fees
  // ============================================
  console.log("\n4. Collect accumulated trading fees");

  const collectFeesOp = sdk.ekuboCollectFees({
    target: EKUBO_ADAPTER,
  });
  console.log("   Collect fees operation:", {
    target: collectFeesOp.target,
    selector: collectFeesOp.selector,
  });

  const collectFeesCall = sdk.buildCall([collectFeesOp]);
  console.log("   Collect fees call built");

  // ============================================
  // 5. Harvest rewards (e.g., STRK incentives)
  // ============================================
  console.log("\n5. Harvest STRK rewards");

  // Note: proof and rewardContract would come from Ekubo's reward API
  const mockRewardContract =
    "123456789"; // This would be the actual reward contract
  const mockProof = ["0x123", "0x456", "0x789"]; // Merkle proof from Ekubo

  const harvestOp = sdk.ekuboHarvest({
    target: EKUBO_ADAPTER,
    rewardContract: mockRewardContract,
    id: "35", // Claim ID from Ekubo's reward API
    amount: "1000000000000000000", // 1 STRK reward
    proof: mockProof,
    rewardToken: TOKENS.STRK,
  });
  console.log("   Harvest operation:", {
    target: harvestOp.target,
    selector: harvestOp.selector,
  });

  const harvestCall = sdk.buildCall([harvestOp]);
  console.log("   Harvest call built");

  // ============================================
  // 6. Full LP management cycle
  // ============================================
  console.log("\n6. Full LP management: Approve + Deposit + Collect fees");

  const fullCycleOps = [
    sdk.approve({
      target: TOKENS.WBTC,
      spender: EKUBO_ADAPTER,
      amount: wbtcAmount,
    }),
    sdk.approve({
      target: TOKENS.SolvBTC,
      spender: EKUBO_ADAPTER,
      amount: solvBtcAmount,
    }),
    sdk.ekuboDepositLiquidity({
      target: EKUBO_ADAPTER,
      amount0: wbtcAmount,
      amount1: solvBtcAmount,
    }),
    sdk.ekuboCollectFees({
      target: EKUBO_ADAPTER,
    }),
  ];

  const fullCycleCall = sdk.buildCall(fullCycleOps);
  console.log("   Full cycle call:", {
    contractAddress: fullCycleCall.contractAddress,
    entrypoint: fullCycleCall.entrypoint,
    operationCount: fullCycleOps.length,
    calldataLength: (fullCycleCall.calldata as string[]).length,
  });

  // ============================================
  // 7. Withdraw all and collect fees
  // ============================================
  console.log("\n7. Full exit: Withdraw all + Collect fees");

  const exitOps = [
    sdk.ekuboWithdrawLiquidity({
      target: EKUBO_ADAPTER,
      ratioWad: "1000000000000000000", // 100% withdrawal (1 WAD)
      minToken0: "0",
      minToken1: "0",
    }),
    sdk.ekuboCollectFees({
      target: EKUBO_ADAPTER,
    }),
  ];

  const exitCall = sdk.buildCall(exitOps);
  console.log("   Exit call:", {
    contractAddress: exitCall.contractAddress,
    entrypoint: exitCall.entrypoint,
    operationCount: exitOps.length,
  });

  console.log("\n=== Ekubo LP Example Complete ===");
  console.log("\nNotes:");
  console.log("- ratioWad uses WAD format (1e18 = 100%)");
  console.log("- amount0/amount1 correspond to the pool's token ordering");
  console.log("- harvest requires a valid merkle proof from Ekubo's reward system");
}

testEkuboOperations().catch(console.error);

export { testEkuboOperations };
