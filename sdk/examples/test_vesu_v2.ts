/**
 * Example: Vesu V2 Operations with VaultCuratorSDK
 * Demonstrates lending/borrowing with modify_position
 */

import { VaultCuratorSDK } from "../src/curator";

// Token addresses (from test.json)
const TOKENS = {
  WBTC: "1806018566677800621296032626439935115720767031724401394291089442012247156652",
  USDC: "2368576823837625528275935341135881659748932889268308403712618244410713532584",
  USDT: "2967174050445828070862061291903957281356339325911846264948421066253307482040",
  wstETH:
    "154717502686997779505242937237748798500912348117963555524611254740330341259",
};

const VESU_POOL =
  "1326796927197022071246993880086420967181713746138493709882850328569146018479";

const VAULT_ALLOCATOR =
  "3148260697098218922501559176188655100084124891713026095862682167186975521235";

async function testVesuV2Operations() {
  console.log("=== Vesu V2 Operations Example ===\n");

  // Load the SDK with test config
  const sdk = VaultCuratorSDK.fromFile("./examples/test.json");

  // Example amounts
  const collateralAmount = "100000000"; // 1 WBTC (8 decimals)
  const borrowAmount = "50000000"; // 50 USDC (6 decimals)

  // ============================================
  // 1. Approve WBTC for Vesu pool
  // ============================================
  console.log("1. Approve WBTC for Vesu pool");

  const approveWBTC = sdk.approve({
    target: TOKENS.WBTC,
    spender: VESU_POOL,
    amount: collateralAmount,
  });
  console.log("   Approve operation created:", {
    target: approveWBTC.target,
  });

  // ============================================
  // 2. Add collateral (WBTC) to Vesu
  // ============================================
  console.log("\n2. Add WBTC collateral to Vesu");

  const addCollateralOp = sdk.modifyPositionV2({
    target: VESU_POOL,
    collateral_asset: TOKENS.WBTC,
    debt_asset: TOKENS.USDC,
    user: VAULT_ALLOCATOR,
    collateral: {
      denomination: "Native",
      value: {
        abs: collateralAmount,
        is_negative: false, // positive = add collateral
      },
    },
    debt: {
      denomination: "Native",
      value: {
        abs: "0",
        is_negative: false,
      },
    },
  });
  console.log("   Add collateral operation:", {
    target: addCollateralOp.target,
    selector: addCollateralOp.selector,
  });

  const addCollateralCall = sdk.buildCall([approveWBTC, addCollateralOp]);
  console.log("   Combined call built with", (addCollateralCall.calldata as string[]).length, "elements");

  // ============================================
  // 3. Borrow USDC against WBTC collateral
  // ============================================
  console.log("\n3. Borrow USDC against WBTC collateral");

  const borrowOp = sdk.modifyPositionV2({
    target: VESU_POOL,
    collateral_asset: TOKENS.WBTC,
    debt_asset: TOKENS.USDC,
    user: VAULT_ALLOCATOR,
    collateral: {
      denomination: "Native",
      value: {
        abs: "0",
        is_negative: false,
      },
    },
    debt: {
      denomination: "Native",
      value: {
        abs: borrowAmount,
        is_negative: false, // positive = borrow
      },
    },
  });
  console.log("   Borrow operation:", {
    target: borrowOp.target,
    selector: borrowOp.selector,
  });

  const borrowCall = sdk.buildCall([borrowOp]);
  console.log("   Borrow call built");

  // ============================================
  // 4. Repay debt (USDC)
  // ============================================
  console.log("\n4. Repay USDC debt");

  const repayOp = sdk.modifyPositionV2({
    target: VESU_POOL,
    collateral_asset: TOKENS.WBTC,
    debt_asset: TOKENS.USDC,
    user: VAULT_ALLOCATOR,
    collateral: {
      denomination: "Native",
      value: {
        abs: "0",
        is_negative: false,
      },
    },
    debt: {
      denomination: "Native",
      value: {
        abs: borrowAmount,
        is_negative: true, // negative = repay
      },
    },
  });
  console.log("   Repay operation:", {
    target: repayOp.target,
    selector: repayOp.selector,
  });

  // ============================================
  // 5. Remove collateral (WBTC)
  // ============================================
  console.log("\n5. Remove WBTC collateral");

  const removeCollateralOp = sdk.modifyPositionV2({
    target: VESU_POOL,
    collateral_asset: TOKENS.WBTC,
    debt_asset: TOKENS.USDC,
    user: VAULT_ALLOCATOR,
    collateral: {
      denomination: "Native",
      value: {
        abs: collateralAmount,
        is_negative: true, // negative = remove collateral
      },
    },
    debt: {
      denomination: "Native",
      value: {
        abs: "0",
        is_negative: false,
      },
    },
  });
  console.log("   Remove collateral operation:", {
    target: removeCollateralOp.target,
    selector: removeCollateralOp.selector,
  });

  // ============================================
  // 6. Full leverage cycle
  // ============================================
  console.log("\n6. Full leverage cycle: Approve + Add collateral + Borrow");

  const leverageCycleOps = [
    sdk.approve({
      target: TOKENS.WBTC,
      spender: VESU_POOL,
      amount: collateralAmount,
    }),
    sdk.modifyPositionV2({
      target: VESU_POOL,
      collateral_asset: TOKENS.WBTC,
      debt_asset: TOKENS.USDC,
      user: VAULT_ALLOCATOR,
      collateral: {
        denomination: "Native",
        value: { abs: collateralAmount, is_negative: false },
      },
      debt: {
        denomination: "Native",
        value: { abs: borrowAmount, is_negative: false },
      },
    }),
  ];

  const leverageCall = sdk.buildCall(leverageCycleOps);
  console.log("   Leverage call:", {
    contractAddress: leverageCall.contractAddress,
    entrypoint: leverageCall.entrypoint,
    operationCount: leverageCycleOps.length,
  });

  // ============================================
  // 7. Using wstETH as collateral
  // ============================================
  console.log("\n7. Alternative: wstETH collateral, USDT debt");

  const wstETHCollateralOp = sdk.modifyPositionV2({
    target: VESU_POOL,
    collateral_asset: TOKENS.wstETH,
    debt_asset: TOKENS.USDT,
    user: VAULT_ALLOCATOR,
    collateral: {
      denomination: "Native",
      value: {
        abs: "1000000000000000000", // 1 wstETH
        is_negative: false,
      },
    },
    debt: {
      denomination: "Native",
      value: {
        abs: "1000000", // 1 USDT
        is_negative: false,
      },
    },
  });
  console.log("   wstETH/USDT position:", {
    target: wstETHCollateralOp.target,
  });

  console.log("\n=== Vesu V2 Example Complete ===");
  console.log("\nNotes:");
  console.log("- is_negative: false for collateral = deposit, true = withdraw");
  console.log("- is_negative: false for debt = borrow, true = repay");
  console.log("- denomination: 'Native' uses raw amounts, 'Assets' uses scaled amounts");
}

testVesuV2Operations().catch(console.error);

export { testVesuV2Operations };
