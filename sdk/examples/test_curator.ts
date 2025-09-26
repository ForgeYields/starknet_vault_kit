import { VaultCuratorSDK, VaultConfigData } from "../src/curator";
import * as fs from "fs";
import * as path from "path";

// Load the configuration
const configPath = path.join(__dirname, "v0DwBTC.json");
const config: VaultConfigData = JSON.parse(fs.readFileSync(configPath, "utf8"));

// Initialize the curator SDK
const curator = new VaultCuratorSDK(config);

try {
  console.log("🚀 Testing VaultCuratorSDK with v0DwBTC configuration");
  console.log("📝 Vault address:", config.metadata.vault);
  console.log("📝 Manager address:", config.metadata.manager);
  console.log("📝 Available leafs:", config.leafs.length);

  // Test 1: Approve WBTC for v0DwBTC vault (leaf 0)
  console.log("\n1️⃣ Testing approve WBTC for v0DwBTC vault");
  const approveCall = curator.approve({
    target:
      "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
    spender: config.metadata.vault, // v0DwBTC vault
    amount: "1000000000000000000", // 1 WBTC (18 decimals)
  });
  console.log(
    "✅ Approve call generated:",
    JSON.stringify(approveCall, null, 2)
  );

  // Test 2: Bring liquidity (leaf 1)
  console.log("\n2️⃣ Testing bring liquidity");
  const bringLiquidityCall = curator.bringLiquidity({
    amount: "1000000000000000000", // 1 WBTC
  });
  console.log(
    "✅ Bring liquidity call generated:",
    JSON.stringify(bringLiquidityCall, null, 2)
  );

  // Test 3: Bring liquidity with manual approval (since helper needs underlying_asset)
  console.log("\n3️⃣ Testing bring liquidity with manual approval");
  const bringLiquidityWithApprovalCalls = [
    curator.approve({
      target: "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
      spender: config.metadata.vault, // v0DwBTC vault
      amount: "1000000000000000000" // 1 WBTC
    }),
    curator.bringLiquidity({
      amount: "1000000000000000000" // 1 WBTC
    })
  ];
  console.log(
    "✅ Bring liquidity with approval calls:",
    JSON.stringify(bringLiquidityWithApprovalCalls, null, 2)
  );

  // Test 4: Deposit USDC for USD0D (leaf 5)
  console.log("\n4️⃣ Testing deposit USDC for USD0D");
  const depositCall = curator.deposit({
    target:
      "2709678016695957534936729098950657878497757149603227109909646125304011384656", // USD0D
    assets: "1000000", // 1 USDC (6 decimals)
    receiver: config.metadata.vault,
  });
  console.log(
    "✅ Deposit call generated:",
    JSON.stringify(depositCall, null, 2)
  );

  // Test 5: Mint USD0D (leaf 6)
  console.log("\n5️⃣ Testing mint USD0D");
  const mintCall = curator.mint({
    target:
      "2709678016695957534936729098950657878497757149603227109909646125304011384656", // USD0D
    shares: "1000000", // 1 USD0D share
    receiver: config.metadata.vault,
  });
  console.log("✅ Mint call generated:", JSON.stringify(mintCall, null, 2));

  // Test 6: Request redeem USD0D (leaf 7)
  console.log("\n6️⃣ Testing request redeem USD0D");
  const requestRedeemCall = curator.requestRedeem({
    target:
      "2709678016695957534936729098950657878497757149603227109909646125304011384656", // USD0D
    shares: "1000000", // 1 USD0D share
    receiver: config.metadata.vault,
    owner: config.metadata.vault,
  });
  console.log(
    "✅ Request redeem call generated:",
    JSON.stringify(requestRedeemCall, null, 2)
  );

  // Test 7: Claim redeem USD0D (leaf 8)
  console.log("\n7️⃣ Testing claim redeem USD0D");
  const claimRedeemCall = curator.claimRedeem({
    target:
      "2709678016695957534936729098950657878497757149603227109909646125304011384656", // USD0D
    id: "1", // redeem request ID
  });
  console.log(
    "✅ Claim redeem call generated:",
    JSON.stringify(claimRedeemCall, null, 2)
  );

  // Test 8: Multi route swap STRK for WBTC (leaf 10)
  console.log("\n8️⃣ Testing multi route swap STRK for WBTC");
  const multiRouteSwapCall = curator.multiRouteSwap({
    target:
      "2713156811396216779458670622113005846204516911477148958318062236521943541257", // AVNU router
    sell_token_address:
      "2009894490435840142178314390393166646092438090257831307886760648929397478285", // STRK
    sell_token_amount: "1000000000000000000", // 1 STRK
    buy_token_address:
      "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
    buy_token_amount: "100000000", // 0.001 WBTC expected
    buy_token_min_amount: "90000000", // 0.0009 WBTC minimum
    integrator_fee_amount_bps: "0",
    integrator_fee_recipient: config.metadata.vault,
    beneficiary: config.metadata.vault,
    routes: [
      {
        sell_token:
          "2009894490435840142178314390393166646092438090257831307886760648929397478285", // STRK
        buy_token:
          "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
        exchange_address: "0x123", // Mock exchange
        percent: "100", // 100%
        additional_swap_params: [],
      },
    ],
  });
  console.log(
    "✅ Multi route swap call generated:",
    JSON.stringify(multiRouteSwapCall, null, 2)
  );

  // Test 9: Modify position V2 (leaf 3)
  console.log("\n9️⃣ Testing modify position V2");
  const modifyPositionV2Call = curator.modifyPositionV2({
    target:
      "1326796927197022071246993880086420967181713746138493709882850328569146018479", // Pool contract
    collateral_asset:
      "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
    debt_asset:
      "2368576823837625528275935341135881659748932889268308403712618244410713532584", // USDC
    user: config.metadata.vault,
    collateral: {
      denomination: "Assets",
      value: {
        abs: "1000000000000000000", // 1 WBTC
        is_negative: false,
      },
    },
    debt: {
      denomination: "Assets",
      value: {
        abs: "5000000000", // 5000 USDC
        is_negative: false,
      },
    },
  });
  console.log(
    "✅ Modify position V2 call generated:",
    JSON.stringify(modifyPositionV2Call, null, 2)
  );

  // Test 10: Helper methods
  console.log("\n🔟 Testing helper methods");

  // Deposit helper with manual approval (since helper needs underlying_asset)
  const depositWithApprovalCalls = [
    curator.approve({
      target: "2368576823837625528275935341135881659748932889268308403712618244410713532584", // USDC
      spender: "2709678016695957534936729098950657878497757149603227109909646125304011384656", // USD0D
      amount: "1000000" // 1 USDC
    }),
    curator.deposit({
      target: "2709678016695957534936729098950657878497757149603227109909646125304011384656", // USD0D
      assets: "1000000", // 1 USDC
      receiver: config.metadata.vault,
    })
  ];
  console.log(
    "✅ Deposit helper with approval:",
    JSON.stringify(depositWithApprovalCalls, null, 2)
  );

  // Request redeem helper
  const requestRedeemHelperCalls = curator.requestRedeemHelper(
    "2709678016695957534936729098950657878497757149603227109909646125304011384656", // USD0D
    "1000000" // 1 USD0D share
  );
  console.log(
    "✅ Request redeem helper:",
    JSON.stringify(requestRedeemHelperCalls, null, 2)
  );

  // Multi route swap helper with approval
  const swapHelperCalls = curator.multiRouteSwapHelper(
    {
      target:
        "2713156811396216779458670622113005846204516911477148958318062236521943541257", // AVNU router
      sell_token_address:
        "2009894490435840142178314390393166646092438090257831307886760648929397478285", // STRK
      sell_token_amount: "1000000000000000000", // 1 STRK
      buy_token_address:
        "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
      buy_token_amount: "100000000", // 0.001 WBTC expected
      buy_token_min_amount: "90000000", // 0.0009 WBTC minimum
      integrator_fee_amount_bps: "0",
      integrator_fee_recipient: config.metadata.vault,
      routes: [
        {
          sell_token:
            "2009894490435840142178314390393166646092438090257831307886760648929397478285", // STRK
          buy_token:
            "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
          exchange_address: "0x123", // Mock exchange
          percent: "100", // 100%
          additional_swap_params: [],
        },
      ],
    },
    { withApproval: true }
  );
  console.log(
    "✅ Multi route swap helper with approval:",
    JSON.stringify(swapHelperCalls, null, 2)
  );

  // ModifyPositionV2 helper with approval
  const modifyPositionV2HelperCalls = curator.ModifyPositionV2Helper(
    {
      target:
        "1326796927197022071246993880086420967181713746138493709882850328569146018479", // Pool contract
      collateral_asset:
        "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
      debt_asset:
        "2368576823837625528275935341135881659748932889268308403712618244410713532584", // USDC
      collateral: {
        denomination: "Assets",
        value: {
          abs: "1000000000000000000", // 1 WBTC
          is_negative: false,
        },
      },
      debt: {
        denomination: "Assets",
        value: {
          abs: "5000000000", // 5000 USDC
          is_negative: false,
        },
      },
    },
    {
      target:
        "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
      spender:
        "1326796927197022071246993880086420967181713746138493709882850328569146018479", // Pool contract
      amount: "1000000000000000000", // 1 WBTC
    }
  );
  console.log(
    "✅ ModifyPositionV2 helper with approval:",
    JSON.stringify(modifyPositionV2HelperCalls, null, 2)
  );

  console.log("\n🎉 All tests completed successfully!");
} catch (error) {
  console.error("❌ Test failed:", error);
}
