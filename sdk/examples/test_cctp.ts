import { VaultCuratorSDK, BridgeTokenCctpParams } from "../src/index";
import { CalldataBuilder } from "../src/utils/calldata";
import * as fs from "fs";
import * as path from "path";

console.log("Testing CCTP bridge methods with testVault.json configuration");

// Load the testVault.json configuration
const configPath = path.join(__dirname, "testVault.json");
const vaultConfig = JSON.parse(fs.readFileSync(configPath, "utf-8"));

console.log(`\nLoaded config from: ${configPath}`);
console.log(`   Vault: ${vaultConfig.metadata.vault}`);
console.log(`   Leafs: ${vaultConfig.metadata.leaf_used}/${vaultConfig.metadata.tree_capacity}`);

// Find the CCTP bridge leaf (deposit_for_burn)
const cctpLeaf = vaultConfig.leafs.find(
  (leaf: any) => leaf.description && leaf.description.includes("CCTP: burn")
);

if (!cctpLeaf) {
  console.log("\nNo CCTP bridge leaf found in testVault.json");
  console.log("This is expected if CCTP is not configured in the test vault.");
  console.log("\nTo test CCTP, ensure your vault configuration includes:");
  console.log("  1. An approve leaf for the burn token to the CCTP middleware");
  console.log("  2. A deposit_for_burn leaf for the CCTP middleware");
  console.log("\nExample leaf structure for deposit_for_burn:");
  console.log(`  {
    "description": "CCTP: burn USDC for USDC on domain 0 to recipient ...",
    "selector": "<deposit_for_burn selector>",
    "target": "<cctp_middleware_address>",
    "argument_addresses": [
      "<destination_domain>",
      "<mint_recipient_low>",
      "<mint_recipient_high>",
      "<burn_token>",
      "<token_to_claim>",
      "<destination_caller_low>",
      "<destination_caller_high>"
    ]
  }`);
  process.exit(0);
}

// Find the approve leaf for burn_token to CCTP middleware
const approveBurnTokenLeaf = vaultConfig.leafs.find(
  (leaf: any) => leaf.description && leaf.description.includes("cctp_middleware") && !leaf.description.includes("CCTP: burn")
);

if (!approveBurnTokenLeaf) {
  throw new Error("Could not find CCTP approve leaf in config");
}

console.log(`\nFound required CCTP leafs:`);
console.log(`   1. ${approveBurnTokenLeaf.description}`);
console.log(`      - Burn Token: ${approveBurnTokenLeaf.target}`);
console.log(`      - Spender (CCTP Middleware): ${approveBurnTokenLeaf.argument_addresses[0]}`);
console.log(`   2. ${cctpLeaf.description}`);
console.log(`      - Target (CCTP Middleware): ${cctpLeaf.target}`);
console.log(`      - Destination Domain: ${cctpLeaf.argument_addresses[0]}`);
console.log(`      - Burn Token: ${cctpLeaf.argument_addresses[3]}`);
console.log(`      - Token to Claim: ${cctpLeaf.argument_addresses[4]}`);

try {
  const curator = new VaultCuratorSDK(vaultConfig);

  console.log("\nVaultCuratorSDK initialized successfully");

  // Bridge amount: example with 100 USDC (6 decimals)
  const bridgeAmount = "100000000"; // 100 USDC with 6 decimals
  const maxFee = "1000000"; // 1 USDC max fee

  // Reconstruct mint_recipient u256 from low and high parts
  const mintRecipientLow = BigInt(cctpLeaf.argument_addresses[1]);
  const mintRecipientHigh = BigInt(cctpLeaf.argument_addresses[2]);
  const mintRecipient = (mintRecipientHigh << 128n) | mintRecipientLow;

  // Reconstruct destination_caller u256 from low and high parts
  const destinationCallerLow = BigInt(cctpLeaf.argument_addresses[5]);
  const destinationCallerHigh = BigInt(cctpLeaf.argument_addresses[6]);
  const destinationCaller = (destinationCallerHigh << 128n) | destinationCallerLow;

  // Step 1: Approve burn_token for CCTP middleware
  console.log("\n1. Generating approve burn token call for CCTP");
  const approveBurnTokenCall = curator.approve({
    target: approveBurnTokenLeaf.target, // burn token
    spender: approveBurnTokenLeaf.argument_addresses[0], // CCTP middleware
    amount: bridgeAmount,
  });

  console.log("   Approve burn token call structure:");
  console.log("      - contractAddress:", approveBurnTokenCall.contractAddress);
  console.log("      - entrypoint:", approveBurnTokenCall.entrypoint);
  console.log("      - calldata length:", approveBurnTokenCall.calldata ? Array.isArray(approveBurnTokenCall.calldata) ? approveBurnTokenCall.calldata.length : "N/A" : 0);

  // Step 2: Bridge token via CCTP (deposit_for_burn)
  console.log("\n2. Generating bridgeTokenCctp call (deposit_for_burn)");
  const bridgeCall = curator.bridgeTokenCctp({
    burn_token: cctpLeaf.argument_addresses[3],
    token_to_claim: cctpLeaf.argument_addresses[4],
    amount: bridgeAmount,
    destination_domain: cctpLeaf.argument_addresses[0],
    mint_recipient: mintRecipient.toString(),
    destination_caller: destinationCaller.toString(),
    max_fee: maxFee,
    min_finality_threshold: "1", // Minimum finality threshold
  });

  console.log("   Bridge call structure:");
  console.log("      - contractAddress:", bridgeCall.contractAddress);
  console.log("      - entrypoint:", bridgeCall.entrypoint);
  console.log("      - calldata length:", bridgeCall.calldata ? Array.isArray(bridgeCall.calldata) ? bridgeCall.calldata.length : "N/A" : 0);
  console.log("      - calldata (JSON):", JSON.stringify(bridgeCall.calldata, null, 2));

  // Format calldata for block explorer
  if (bridgeCall.calldata && Array.isArray(bridgeCall.calldata)) {
    console.log("\n   Bridge calldata formatted for block explorer (Voyager/Starkscan):");
    console.log("   " + "=".repeat(60));
    const formattedCalldata = CalldataBuilder.formatCalldataForExplorer(bridgeCall.calldata as string[]);
    console.log(formattedCalldata.split('\n').map(line => "   " + line).join('\n'));
    console.log("   " + "=".repeat(60));
  }

  // Verify all calls were generated
  if (approveBurnTokenCall.entrypoint && bridgeCall.entrypoint) {
    console.log("\n   All CCTP bridge calls generated successfully");
  } else {
    throw new Error("CCTP bridge call generation failed");
  }

  console.log("\nCCTP bridge calldata computed successfully!");
  console.log("\nSummary:");
  console.log("   Loaded testVault.json configuration");
  console.log("   Found 2 required leafs (approve burn token + deposit_for_burn)");
  console.log("   Generated 2 calls for complete CCTP bridge operation:");
  console.log("      1. Approve burn token for bridge amount");
  console.log("      2. Bridge token via CCTP (deposit_for_burn)");
  console.log(`   Burn Token: ${cctpLeaf.argument_addresses[3]}`);
  console.log(`   Token to Claim: ${cctpLeaf.argument_addresses[4]}`);
  console.log(`   Destination Domain: ${cctpLeaf.argument_addresses[0]}`);
  console.log(`   Mint Recipient: ${mintRecipient.toString()}`);
  console.log(`   Bridge Amount: ${bridgeAmount}`);
  console.log(`   Max Fee: ${maxFee}`);

} catch (error) {
  console.error("\nTest failed:", error);
  process.exit(1);
}
