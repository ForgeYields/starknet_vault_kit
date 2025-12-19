import { Account, RpcProvider } from "starknet";
import dotenv from "dotenv";
import { readConfigs } from "./configs/utils";
import { getNetworkEnv } from "./utils";
import { saveVaultDeployment } from "./utils/deployment";
import readline from "readline";

dotenv.config({ path: __dirname + "/../.env" });

const provider = new RpcProvider({ nodeUrl: process.env.RPC });
const owner = new Account({
  provider: provider,
  address: process.env.ACCOUNT_ADDRESS as string,
  signer: process.env.ACCOUNT_PK as string,
});

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

export async function deployManager(
  envNetwork: string,
  vaultAllocatorAddress: string,
  vaultSymbol?: string
) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];

  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const classHash = networkConfig.hash?.Manager;
  if (!classHash) {
    throw new Error(
      `Manager class hash not found for network: ${envNetwork}. Please declare the contract first.`
    );
  }

  try {
    console.log(`Deploying Manager with constructor params:`);
    console.log(`  Owner: ${owner.address}`);
    console.log(`  VaultAllocator: ${vaultAllocatorAddress}`);

    const deployResponse = await owner.deployContract({
      classHash: classHash,
      constructorCalldata: [owner.address, vaultAllocatorAddress],
    });

    console.log(`Manager deployed successfully!`);
    console.log(`Contract Address: ${deployResponse.contract_address}`);
    console.log(`Transaction Hash: ${deployResponse.transaction_hash}`);

    if (vaultSymbol) {
      saveVaultDeployment(
        envNetwork,
        vaultSymbol,
        "manager",
        deployResponse.contract_address,
        deployResponse.transaction_hash
      );
    }

    return deployResponse.contract_address;
  } catch (error) {
    console.error("Error deploying Manager:", error);
    throw error;
  }
}

async function main() {
  try {
    const envNetwork = await getNetworkEnv(provider);

    console.log("Initializing Manager deployment process...\n");

    const vaultAllocatorAddress = await askQuestion(
      "VaultAllocator address (required): "
    );

    if (!vaultAllocatorAddress) {
      throw new Error("VaultAllocator address is required");
    }

    const vaultSymbol = await askQuestion(
      "Vault symbol (for saving deployment, leave empty to skip): "
    );

    console.log("\nDeployment Summary:");
    console.log(`Network: ${envNetwork}`);
    console.log(`Owner: ${owner.address}`);
    console.log(`VaultAllocator: ${vaultAllocatorAddress}`);
    if (vaultSymbol) {
      console.log(`Vault Symbol: ${vaultSymbol}`);
    }

    console.log("\nDeploying Manager...");
    const managerAddress = await deployManager(
      envNetwork,
      vaultAllocatorAddress,
      vaultSymbol || undefined
    );

    console.log("\nDeployment completed successfully!");
    console.log(`Manager Address: ${managerAddress}`);
  } catch (error) {
    console.error("\nDeployment failed:", error);
    throw error;
  } finally {
    rl.close();
  }
}

main().catch(console.error);
