import { VaultCuratorSDK, BridgeTokenStarkgateParams, ClaimTokenStarkgateParams } from "../src/index";
import { CalldataBuilder } from "../src/utils/calldata";
import * as fs from "fs";
import * as path from "path";

// This is a simple verification test for the new Starkgate methods
console.log("🧪 Testing Starkgate methods with testVault.json configuration");

// Load the testVault.json configuration
const configPath = path.join(__dirname, "testVault.json");
const vaultConfig = JSON.parse(fs.readFileSync(configPath, "utf-8"));

console.log(`\n📄 Loaded config from: ${configPath}`);
console.log(`   Vault: ${vaultConfig.metadata.vault}`);
console.log(`   Leafs: ${vaultConfig.metadata.leaf_used}/${vaultConfig.metadata.tree_capacity}`);

// Find the "Approve starkgate_bridge_middleware to spend USDC" leaf
const approveLeaf = vaultConfig.leafs.find(
  (leaf: any) => leaf.description === "Approve starkgate_bridge_middleware to spend USDC"
);

if (!approveLeaf) {
  throw new Error("Could not find 'Approve starkgate_bridge_middleware to spend USDC' leaf in config");
}

// Find the "Initiate token withdraw USDC" leaf
const initiateWithdrawLeaf = vaultConfig.leafs.find(
  (leaf: any) => leaf.description === "Initiate token withdraw USDC"
);

if (!initiateWithdrawLeaf) {
  throw new Error("Could not find 'Initiate token withdraw USDC' leaf in config");
}

console.log(`\n✅ Found required leafs:`);
console.log(`   1. ${approveLeaf.description}`);
console.log(`      - USDC Token: ${approveLeaf.target}`);
console.log(`      - Spender (Starkgate): ${approveLeaf.argument_addresses[0]}`);
console.log(`   2. ${initiateWithdrawLeaf.description}`);
console.log(`      - Target: ${initiateWithdrawLeaf.target}`);
console.log(`      - L1 Token: ${initiateWithdrawLeaf.argument_addresses[0]}`);
console.log(`      - L1 Recipient: ${initiateWithdrawLeaf.argument_addresses[1]}`);

try {
  const curator = new VaultCuratorSDK(vaultConfig);

  console.log("\n✅ VaultCuratorSDK initialized successfully");

  // Step 1: Approve Starkgate middleware to spend 1 USDC
  console.log("\n1️⃣ Generating approve call for Starkgate middleware");
  const approveCall = curator.approve({
    target: approveLeaf.target, // USDC token
    spender: approveLeaf.argument_addresses[0], // Starkgate middleware
    amount: "1000000", // 1 USDC (6 decimals)
  });

  console.log("   ✅ Approve call structure:");
  console.log("      - contractAddress:", approveCall.contractAddress || "(not set - need manager in config)");
  console.log("      - entrypoint:", approveCall.entrypoint);
  console.log("      - calldata length:", approveCall.calldata ? Array.isArray(approveCall.calldata) ? approveCall.calldata.length : "N/A" : 0);

  // Format approve calldata for block explorer
  if (approveCall.calldata && Array.isArray(approveCall.calldata)) {
    console.log("\n   📋 Approve calldata formatted for block explorer:");
    console.log("   " + "=".repeat(60));
    const formattedCalldata = CalldataBuilder.formatCalldataForExplorer(approveCall.calldata as string[]);
    console.log(formattedCalldata.split('\n').map(line => "   " + line).join('\n'));
    console.log("   " + "=".repeat(60));
  }

  // Verify approve call was generated
  if (approveCall.entrypoint && approveCall.calldata && Array.isArray(approveCall.calldata) && approveCall.calldata.length > 0) {
    console.log("\n   ✅ Approve calldata generated successfully");
  } else {
    throw new Error("Approve call generation failed");
  }

  // Step 2: bridgeTokenStarkgate with 1 USDC to the approved recipient
  console.log("\n2️⃣ Generating bridgeTokenStarkgate call with 1 USDC");
  const bridgeCall = curator.bridgeTokenStarkgate({
    l1_token: initiateWithdrawLeaf.argument_addresses[0],
    l1_recipient: initiateWithdrawLeaf.argument_addresses[1],
    amount: "1000000", // 1 USDC (6 decimals)
  });

  console.log("   ✅ Call structure:");
  console.log("      - contractAddress:", bridgeCall.contractAddress || "(not set - need manager in config)");
  console.log("      - entrypoint:", bridgeCall.entrypoint);
  console.log("      - calldata length:", bridgeCall.calldata ? Array.isArray(bridgeCall.calldata) ? bridgeCall.calldata.length : "N/A" : 0);
  console.log("      - calldata (JSON):", JSON.stringify(bridgeCall.calldata, null, 2));

  // Format calldata for block explorer
  if (bridgeCall.calldata && Array.isArray(bridgeCall.calldata)) {
    console.log("\n   📋 Calldata formatted for block explorer (Voyager/Starkscan):");
    console.log("   " + "=".repeat(60));
    const formattedCalldata = CalldataBuilder.formatCalldataForExplorer(bridgeCall.calldata as string[]);
    console.log(formattedCalldata.split('\n').map(line => "   " + line).join('\n'));
    console.log("   " + "=".repeat(60));
  }

  // Verify call was generated
  if (bridgeCall.entrypoint && bridgeCall.calldata && Array.isArray(bridgeCall.calldata) && bridgeCall.calldata.length > 0) {
    console.log("   ✅ bridgeTokenStarkgate calldata generated successfully");
    if (!bridgeCall.contractAddress) {
      console.log("   ⚠️  Note: contractAddress is undefined because testVault.json is missing 'manager' field");
      console.log("   ℹ️  In production, this call would be sent to the vault manager contract");
    }
  } else {
    throw new Error("bridgeTokenStarkgate call generation failed");
  }

  console.log("\n🎉 Starkgate bridge calldata computed successfully!");
  console.log("\n📋 Summary:");
  console.log("   ✅ Loaded testVault.json configuration");
  console.log("   ✅ Found 2 required leafs (approve + bridge)");
  console.log("   ✅ Generated 2 calls for complete bridge operation:");
  console.log("      1. Approve Starkgate middleware to spend 1 USDC");
  console.log("      2. Initiate token withdraw to L1");
  console.log(`   ✅ USDC Token: ${approveLeaf.target}`);
  console.log(`   ✅ Starkgate Middleware: ${approveLeaf.argument_addresses[0]}`);
  console.log(`   ✅ L1 Token: ${initiateWithdrawLeaf.argument_addresses[0]}`);
  console.log(`   ✅ L1 Recipient: ${initiateWithdrawLeaf.argument_addresses[1]}`);
  console.log("   ✅ Amount: 1000000 (1 USDC with 6 decimals)");

} catch (error) {
  console.error("\n❌ Test failed:", error);
  process.exit(1);
}
