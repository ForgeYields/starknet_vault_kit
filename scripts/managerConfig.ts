import {
  Account,
  RpcProvider,
  validateAndParseAddress,
} from "starknet";
import dotenv from "dotenv";
import { getNetworkEnv } from "./utils";
import readline from "readline";

dotenv.config({ path: __dirname + "/../.env" });

const provider = new RpcProvider({ nodeUrl: process.env.RPC });
const owner = new Account(
  provider,
  process.env.ACCOUNT_ADDRESS as string,
  process.env.ACCOUNT_PK as string,
  undefined,
  "0x3"
);

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function askQuestion(question: string): Promise<string> {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer.trim());
    });
  });
}

function validateMerkleRoot(value: string): void {
  if (!value || value.length === 0) {
    throw new Error("Merkle root cannot be empty");
  }
  
  if (!value.startsWith("0x")) {
    throw new Error("Merkle root must start with '0x'");
  }
  
  const hexValue = value.slice(2);
  if (!/^[0-9a-fA-F]+$/.test(hexValue)) {
    throw new Error("Merkle root must be a valid hexadecimal value");
  }
}

async function getManagerAddress(): Promise<string> {
  const managerAddress = await askQuestion("Enter manager contract address: ");
  try {
    validateAndParseAddress(managerAddress);
    return managerAddress;
  } catch (error) {
    throw new Error(`Invalid manager address: ${managerAddress}`);
  }
}

async function showConfigMenu(): Promise<string> {
  console.log("\n📋 Manager Configuration Options:");
  console.log("1. Set Manage Root");
  console.log("2. Exit");

  const choice = await askQuestion("\nSelect an option (1-2): ");
  return choice.trim();
}

async function setManageRoot(managerAddress: string): Promise<void> {
  console.log("\n🌳 Set Manage Root");
  console.log("Configure merkle tree root for a strategist target");
  console.log();

  const strategistAddress = await askQuestion("Strategist address (target): ");
  try {
    validateAndParseAddress(strategistAddress);
  } catch (error) {
    throw new Error(`Invalid strategist address: ${strategistAddress}`);
  }

  const merkleRoot = await askQuestion("Merkle tree root (felt252): ");
  validateMerkleRoot(merkleRoot);

  console.log(`\n📋 Configuration Summary:`);
  console.log(`  Manager: ${managerAddress}`);
  console.log(`  Strategist: ${strategistAddress}`);
  console.log(`  Merkle Root: ${merkleRoot}`);

  const confirm = await askQuestion("\nConfirm configuration? (y/n): ");
  if (confirm.toLowerCase() !== "y" && confirm.toLowerCase() !== "yes") {
    console.log("Configuration cancelled.");
    return;
  }

  try {
    const response = await owner.execute({
      contractAddress: managerAddress,
      entrypoint: "set_manage_root",
      calldata: [strategistAddress, merkleRoot],
    });

    console.log("✅ Manage root updated successfully!");
    console.log(`Transaction Hash: ${response.transaction_hash}`);
  } catch (error) {
    console.error("❌ Error setting manage root:", error);
    throw error;
  }
}

async function main() {
  try {
    const envNetwork = await getNetworkEnv(provider);
    console.log(`🌐 Connected to network: ${envNetwork}`);
    console.log(`👤 Using account: ${owner.address}`);

    const managerAddress = await getManagerAddress();

    while (true) {
      const choice = await showConfigMenu();

      switch (choice) {
        case "1":
          await setManageRoot(managerAddress);
          break;

        case "2":
          console.log("👋 Goodbye!");
          return;

        default:
          console.log("❌ Invalid choice. Please select 1-2.");
          break;
      }

      console.log("\n" + "=".repeat(50));
    }
  } catch (error) {
    console.error("\n❌ Configuration failed:", error);
    throw error;
  } finally {
    rl.close();
  }
}

main().catch(console.error);