import { VaultCuratorSDK, BridgeTokenHyperlaneParams } from "../src/index";
import { CalldataBuilder } from "../src/utils/calldata";
import * as fs from "fs";
import * as path from "path";

console.log("🧪 Testing Hyperlane bridge methods with testVault.json configuration");

// Load the testVault.json configuration
const configPath = path.join(__dirname, "testVault.json");
const vaultConfig = JSON.parse(fs.readFileSync(configPath, "utf-8"));

console.log(`\n📄 Loaded config from: ${configPath}`);
console.log(`   Vault: ${vaultConfig.metadata.vault}`);
console.log(`   Leafs: ${vaultConfig.metadata.leaf_used}/${vaultConfig.metadata.tree_capacity}`);

// Find the Hyperlane bridge leaf
const hyperlaneLeaf = vaultConfig.leafs.find(
  (leaf: any) => leaf.description && leaf.description.includes("Hyperlane: bridge")
);

if (!hyperlaneLeaf) {
  throw new Error("Could not find Hyperlane bridge leaf in config");
}

// Find the approve leafs for Hyperlane
const approveSourceTokenLeaf = vaultConfig.leafs.find(
  (leaf: any) => leaf.description && leaf.description.includes("hyperlane_middleware") && leaf.description.includes("sUSN")
);

const approveStrkLeaf = vaultConfig.leafs.find(
  (leaf: any) => leaf.description && leaf.description.includes("hyperlane_middleware") && leaf.description.includes("STRK")
);

if (!approveSourceTokenLeaf || !approveStrkLeaf) {
  throw new Error("Could not find Hyperlane approve leafs in config");
}

console.log(`\n✅ Found required Hyperlane leafs:`);
console.log(`   1. ${approveStrkLeaf.description}`);
console.log(`      - STRK Token: ${approveStrkLeaf.target}`);
console.log(`      - Spender (Hyperlane): ${approveStrkLeaf.argument_addresses[0]}`);
console.log(`   2. ${approveSourceTokenLeaf.description}`);
console.log(`      - Source Token: ${approveSourceTokenLeaf.target}`);
console.log(`      - Spender (Hyperlane): ${approveSourceTokenLeaf.argument_addresses[0]}`);
console.log(`   3. ${hyperlaneLeaf.description}`);
console.log(`      - Target: ${hyperlaneLeaf.target}`);
console.log(`      - Source Token: ${hyperlaneLeaf.argument_addresses[0]}`);
console.log(`      - Destination Token: ${hyperlaneLeaf.argument_addresses[1]}`);
console.log(`      - Destination Domain: ${hyperlaneLeaf.argument_addresses[2]}`);
console.log(`      - Recipient: ${hyperlaneLeaf.argument_addresses[3]}`);
console.log(`      - Hook Metadata: ${hyperlaneLeaf.argument_addresses[4]}`);

try {
  const curator = new VaultCuratorSDK(vaultConfig);

  console.log("\n✅ VaultCuratorSDK initialized successfully");

  // Bridge amount: 1 sUSN (18 decimals)
  // Note: Hyperlane bridge fees are paid in STRK and must be approved separately and 
  // are quoted by the quote_gas_payment function on the token to be bridged (e.g. sUSN
  // in this example https://voyager.online/token/0x02411565ef1a14decfbe83d2e987cced918cd752508a3d9c55deb67148d14d17#readFunctions).
  const bridgeAmount = "1000000000000000000"; // 1 sUSN with 18 decimals
  const strkFee = "10178000000000000000"; // ~10.178 STRK fee (18 decimals)

  // Step 1: Approve STRK for fee
  console.log("\n1️⃣ Generating approve STRK call for Hyperlane fee");
  const approveStrkCall = curator.approve({
    target: approveStrkLeaf.target, // STRK token
    spender: approveStrkLeaf.argument_addresses[0], // Hyperlane middleware
    amount: strkFee,
  });

  console.log("   ✅ Approve STRK call structure:");
  console.log("      - contractAddress:", approveStrkCall.contractAddress);
  console.log("      - entrypoint:", approveStrkCall.entrypoint);
  console.log("      - calldata length:", approveStrkCall.calldata ? Array.isArray(approveStrkCall.calldata) ? approveStrkCall.calldata.length : "N/A" : 0);

  // Step 2: Approve source token for bridge amount
  console.log("\n2️⃣ Generating approve source token call for Hyperlane bridge");
  const approveSourceCall = curator.approve({
    target: approveSourceTokenLeaf.target, // Source token (sUSN)
    spender: approveSourceTokenLeaf.argument_addresses[0], // Hyperlane middleware
    amount: bridgeAmount,
  });

  console.log("   ✅ Approve source token call structure:");
  console.log("      - contractAddress:", approveSourceCall.contractAddress);
  console.log("      - entrypoint:", approveSourceCall.entrypoint);
  console.log("      - calldata length:", approveSourceCall.calldata ? Array.isArray(approveSourceCall.calldata) ? approveSourceCall.calldata.length : "N/A" : 0);

  // Step 3: Bridge token via Hyperlane
  console.log("\n3️⃣ Generating bridgeTokenHyperlane call");
  // Reconstruct the full recipient u256 from low and high parts
  const recipientLow = BigInt(hyperlaneLeaf.argument_addresses[3]);
  const recipientHigh = BigInt(hyperlaneLeaf.argument_addresses[4]);
  const recipient = (recipientHigh << 128n) | recipientLow;

  const bridgeCall = curator.bridgeTokenHyperlane({
    source_token: hyperlaneLeaf.argument_addresses[0],
    destination_token: hyperlaneLeaf.argument_addresses[1],
    amount: bridgeAmount,
    destination_domain: hyperlaneLeaf.argument_addresses[2],
    recipient: recipient.toString(),
    strk_fee: strkFee,
  });

  console.log("   ✅ Bridge call structure:");
  console.log("      - contractAddress:", bridgeCall.contractAddress);
  console.log("      - entrypoint:", bridgeCall.entrypoint);
  console.log("      - calldata length:", bridgeCall.calldata ? Array.isArray(bridgeCall.calldata) ? bridgeCall.calldata.length : "N/A" : 0);
  console.log("      - calldata (JSON):", JSON.stringify(bridgeCall.calldata, null, 2));

  // Format calldata for block explorer
  if (bridgeCall.calldata && Array.isArray(bridgeCall.calldata)) {
    console.log("\n   📋 Bridge calldata formatted for block explorer (Voyager/Starkscan):");
    console.log("   " + "=".repeat(60));
    const formattedCalldata = CalldataBuilder.formatCalldataForExplorer(bridgeCall.calldata as string[]);
    console.log(formattedCalldata.split('\n').map(line => "   " + line).join('\n'));
    console.log("   " + "=".repeat(60));
  }

  // Verify all calls were generated
  if (approveStrkCall.entrypoint && approveSourceCall.entrypoint && bridgeCall.entrypoint) {
    console.log("\n   ✅ All Hyperlane bridge calls generated successfully");
  } else {
    throw new Error("Hyperlane bridge call generation failed");
  }

  console.log("\n🎉 Hyperlane bridge calldata computed successfully!");
  console.log("\n📋 Summary:");
  console.log("   ✅ Loaded testVault.json configuration");
  console.log("   ✅ Found 3 required leafs (approve STRK + approve source token + bridge)");
  console.log("   ✅ Generated 3 calls for complete Hyperlane bridge operation:");
  console.log("      1. Approve STRK for fee");
  console.log("      2. Approve source token for bridge amount");
  console.log("      3. Bridge token via Hyperlane");
  console.log(`   ✅ Source Token: ${hyperlaneLeaf.argument_addresses[0]}`);
  console.log(`   ✅ Destination Token: ${hyperlaneLeaf.argument_addresses[1]}`);
  console.log(`   ✅ Destination Domain: ${hyperlaneLeaf.argument_addresses[2]}`);
  console.log(`   ✅ Recipient: ${hyperlaneLeaf.argument_addresses[3]}`);
  console.log(`   ✅ Bridge Amount: ${bridgeAmount} (1 sUSN with 18 decimals)`);
  console.log(`   ✅ STRK Fee: ${strkFee} (~10.178 STRK with 18 decimals)`);

} catch (error) {
  console.error("\n❌ Test failed:", error);
  process.exit(1);
}
