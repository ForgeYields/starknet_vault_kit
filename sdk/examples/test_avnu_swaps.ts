/**
 * AVNU Middleware Test Examples using VaultCuratorSDK
 * 
 * These examples demonstrate how to use the SDK's multiRouteSwapHelper to construct
 * calldata for multi_route_swap operations through the AVNU middleware.
 * 
 * The SDK provides:
 * - multiRouteSwap(): Generates the raw manager-wrapped calldata (with Merkle proofs)
 * - multiRouteSwapHelper(): Convenience wrapper that optionally includes approval + swap
 * 
 * References:
 * - AVNU API: https://starknet.api.avnu.fi
 * - AVNU Ekubo Adapter: https://github.com/avnu-labs/avnu-contracts-v2/blob/48f22111c804f01c91131589f0b2c54f3a06b91b/src/adapters/ekubo_adapter.cairo#L103 
 */

import { VaultCuratorSDK, VaultConfigData } from "../src/curator";
import * as fs from "fs";
import * as path from "path";

// Load the configuration
const configPath = path.join(__dirname, "ntBTC.json");
const config: VaultConfigData = JSON.parse(fs.readFileSync(configPath, "utf8"));

// Initialize the curator SDK
const curator = new VaultCuratorSDK(config);

console.log("🚀 AVNU Middleware multi_route_swap Examples using SDK\n");

try {
  // ============================================================================
  // Example 1: Multi-Hop Route Swap (STRK -> tBTC via intermediate WBTC)
  // ============================================================================

  // Swap 1000 STRK -> tBTC
  // Reference AVNU Quote API: https://starknet.api.avnu.fi/swap/v2/quotes?sellTokenAddress=0x04718f5a0Fc34cC1AF16A1cdee98fFB20C31f5cD61D6Ab07201858f4287c938D&buyTokenAddress=0x04daa17763b286d1e59b97c283C0b8C949994C361e426A28F743c67bDfE9a32f&sellAmount=0x3635C9ADC5DEA00000
  console.log("1️⃣ Example 1: 1000 STRK -> tBTC (through Ekubo)");

  // Use the SDK's multiRouteSwapHelper to construct the swap call
  const example1Calls = curator.multiRouteSwapHelper(
    {
      target: "3599001986704764339689846823962738912073180732388962894432467110279110863503", // AVNU router (0x07F4F683...)
      sell_token_address:
        "2009894490435840142178314390393166646092438090257831307886760648929397478285", // STRK (0x4718f5a0...)
      sell_token_amount: "1000000000000000000000", // 1000 STRK
      buy_token_address:
        "2195538454349598484268483101849850899129107725151793110617059932514648957743", // tBTC (0x4daa17763...)
      buy_token_amount: "0", // unused as min buy amount is computed by the middleware, but can be overwritten
      buy_token_min_amount: "0", // unused as min buy amount is computed by the middleware, but can be overwritten
      integrator_fee_amount_bps: "0",
      integrator_fee_recipient: config.metadata.vault_allocator,
      routes: [
        { // First hop: STRK -> WBTC with Ekubo pool parameters
          sell_token:
            "2009894490435840142178314390393166646092438090257831307886760648929397478285", // STRK
          buy_token:
            "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
          exchange_address: "0x5dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b", // Ekubo
          percent: "1000000000000", // 100% in 10**10 scale
          additional_swap_params: [ // additional swap params as required by Ekubo
            "1806018566677800621296032626439935115720767031724401394291089442012247156652", // token0 (WBTC)
            "2009894490435840142178314390393166646092438090257831307886760648929397478285", // token1 (STRK)
            "0x68db8bac710cb4000000000000000", // fee
            "0xc8", // tick spacing
            "0x0", // extension
            "0x7ffffe04076bda2ab79a947f13420124fa58c8f7b6ffbc94", // sqrt ratio distance
          ],
        },
        { // Second hop: WBTC -> tBTC with Ekubo pool parameters
          sell_token:
            "1806018566677800621296032626439935115720767031724401394291089442012247156652", // WBTC
          buy_token:
            "2195538454349598484268483101849850899129107725151793110617059932514648957743", // tBTC
          exchange_address:
            "0x5dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b", // Ekubo
          percent: "1000000000000", // 100% in 10**10 scale
          additional_swap_params: [
            "1806018566677800621296032626439935115720767031724401394291089442012247156652", // token0 (WBTC)
            "2195538454349598484268483101849850899129107725151793110617059932514648957743", // token1 (tBTC)
            "0x68db8bac710cb4000000000000000", // fee
            "0xc8", // tick spacing
            "0x0", // extension
            "0x7ffffe04076bda2ab79a947f13420124fa58c8f7b6ffbc94", // sqrt ratio distance
          ],
        },
      ],
    },
    { withApproval: true }
  );

  console.log("✅ Example 1 Calls generated (with approval):");
  console.log("  Number of calls:", example1Calls.length);
  example1Calls.forEach((call, idx) => {
    const calldataPreview =
      Array.isArray(call.calldata) && typeof call.calldata[0] !== "string"
        ? (call.calldata as string[]).slice(0, 5).join(", ") + "..."
        : "See full output below";
    console.log(`  Call ${idx}:`, {
      contractAddress: call.contractAddress,
      entrypoint: call.entrypoint,
      calldataPreview,
    });
  });
  // Pool address, fee tier, tick spacing
  const example1SwapCall = example1Calls[1];
  console.log("\n📋 Full call data (Call 0 - Approval):");
  console.log(JSON.stringify(example1Calls[0], null, 2));
  console.log("\n📋 Full call data (Call 1 - Swap):");
  console.log(JSON.stringify(example1SwapCall, null, 2));

  // ============================================================================
  // Example 2: Multi-Hop Route Swap (sUSN -> USDC via intermediate USN)
  // ============================================================================

  // Swap sUSN -> USDC via USN (through Ekubo)
  // Reference AVNU API: https://starknet.api.avnu.fi/swap/v2/quotes?sellTokenAddress=0x2411565ef1a14decfbe83d2e987cced918cd752508a3d9c55deb67148d14d17&buyTokenAddress=0x053C91253BC9682c04929cA02ED00b3E423f6710D2ee7e0D5EBB06F3eCF368A8&sellAmount=0xde0b6b3a7640000
  console.log(
    "\n\n2️⃣ Example 2: sUSN -> USDC via USN (Two Routes through Ekubo)"
  );

  // Use the SDK's multiRouteSwapHelper for a multi-hop swap
  const example2Calls = curator.multiRouteSwapHelper(
    {
      target: "3599001986704764339689846823962738912073180732388962894432467110279110863503", // AVNU router
      sell_token_address:
        "1019618441185390768002816881958434916696817654219012887383733914098652499223", // sUSN (0x2411... converted to decimal)
      sell_token_amount: "1000000000000000000", // 1 sUSN
      buy_token_address:
        "2368576823837625528275935341135881659748932889268308403712618244410713532584", // USDC
      buy_token_amount: "0", // unused as min buy amount is computed by the middleware, but can be overwritten
      buy_token_min_amount: "0", // unused as min buy amount is computed by the middleware, but can be overwritten
      integrator_fee_amount_bps: "0",
      integrator_fee_recipient: config.metadata.vault_allocator,
      routes: [
        { // First hop: sUSN -> USN with Ekubo pool parameters
          sell_token:
            "1019618441185390768002816881958434916696817654219012887383733914098652499223", // sUSN
          buy_token:
            "859269918549784330651726249330358515254775157189780347707111618370103808859", // USN (intermediate, 0x1e65... converted)
          exchange_address:
            "0x5dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b", // Ekubo
          percent: "1000000000000", // 100% in 10**10 scale
          additional_swap_params: [
            "1019618441185390768002816881958434916696817654219012887383733914098652499223", // token0 (sUSN)
            "859269918549784330651726249330358515254775157189780347707111618370103808859", // token1 (USN)
            "0x20c49ba5e353f80000000000000000", // fee
            "0x3e8", // tick spacing
            "0x0", // extension
            "0x7ffffe04076bda2ab79a947f13420124fa58c8f7b6ffbc94", // sqrt ratio distance
          ],
        },
        { // Second hop: USN -> USDC with Ekubo pool parameters
          sell_token:
            "859269918549784330651726249330358515254775157189780347707111618370103808859", // USN
          buy_token:
            "2368576823837625528275935341135881659748932889268308403712618244410713532584", // USDC
          exchange_address:
            "0x5dd3d2f4429af886cd1a3b08289dbcea99a294197e9eb43b0e0325b4b", // Ekubo
          percent: "1000000000000", // 100% in 10**10 scale
          additional_swap_params: [
            "859269918549784330651726249330358515254775157189780347707111618370103808859", // token0 (USN)
            "2368576823837625528275935341135881659748932889268308403712618244410713532584", // token1 (USDC)
            "0x68db8bac710cb4000000000000000", // fee
            "0xc8", // tick spacing
            "0x0", // extension
            "0x7ffffe04076bda2ab79a947f13420124fa58c8f7b6ffbc94", // sqrt ratio distance
          ],
        },
      ],
    },
    { withApproval: true }
  );

  console.log("✅ Example 2 Calls generated (with approval and multi-hop swap):");
  console.log("  Number of calls:", example2Calls.length);
  example2Calls.forEach((call, idx) => {
    console.log(
      `  Call ${idx}: ${call.entrypoint} on ${call.contractAddress}`
    );
  });

  console.log("\n📋 Full call data (Call 0 - Approval):");
  console.log(JSON.stringify(example2Calls[0], null, 2));
  console.log("\n📋 Full call data (Call 1 - Swap with 2 routes):");
  console.log(JSON.stringify(example2Calls[1], null, 2));

  console.log("\n🎉 Examples completed! Use the generated Call objects for transaction execution.");
} catch (error) {
  console.error("❌ Test failed:", error);
}
