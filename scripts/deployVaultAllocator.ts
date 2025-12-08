import { Account, RpcProvider } from "starknet";
import dotenv from "dotenv";
import { readConfigs } from "./configs/utils";
import { getNetworkEnv } from "./utils";
import { saveVaultDeployment } from "./utils/deployment";
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

export async function deployVaultAllocator(
  envNetwork: string,
  vaultSymbol?: string
) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];

  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const classHash = networkConfig.hash?.VaultAllocator;
  if (!classHash) {
    throw new Error(
      `VaultAllocator class hash not found for network: ${envNetwork}. Please declare the contract first.`
    );
  }

  try {
    console.log(`Deploying VaultAllocator with constructor params:`);
    console.log(`  Owner: ${owner.address}`);

    const deployResponse = await owner.deployContract({
      classHash: classHash,
      constructorCalldata: [owner.address],
    });

    console.log(`VaultAllocator deployed successfully!`);
    console.log(`Contract Address: ${deployResponse.contract_address}`);
    console.log(`Transaction Hash: ${deployResponse.transaction_hash}`);

    if (vaultSymbol) {
      saveVaultDeployment(
        envNetwork,
        vaultSymbol,
        "vaultAllocator",
        deployResponse.contract_address,
        deployResponse.transaction_hash
      );
    }

    return deployResponse.contract_address;
  } catch (error) {
    console.error("Error deploying VaultAllocator:", error);
    throw error;
  }
}

async function main() {
  try {
    const envNetwork = await getNetworkEnv(provider);

    console.log("🚀 Initializing VaultAllocator deployment process...\n");

    const vaultSymbol = await askQuestion(
      "Vault symbol (for saving deployment, leave empty to skip): "
    );

    console.log("\n📋 Deployment Summary:");
    console.log(`Network: ${envNetwork}`);
    console.log(`Owner: ${owner.address}`);
    if (vaultSymbol) {
      console.log(`Vault Symbol: ${vaultSymbol}`);
    }

    console.log("\n📦 Deploying VaultAllocator...");
    const vaultAllocatorAddress = await deployVaultAllocator(
      envNetwork,
      vaultSymbol || undefined
    );

    console.log("\n✅ Deployment completed successfully!");
    console.log(`📍 VaultAllocator Address: ${vaultAllocatorAddress}`);
  } catch (error) {
    console.error("\n❌ Deployment failed:", error);
    throw error;
  } finally {
    rl.close();
  }
}

main().catch(console.error);
