import { Account, RpcProvider, CallData } from "starknet";
import dotenv from "dotenv";
import { readConfigs } from "./configs/utils";
import { getNetworkEnv } from "./utils";
import { saveContractDeployment } from "./utils/deployment";
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

// ============================================
// FILL IN THE PARAMETERS BELOW
// ============================================

// Vault allocator address that will control this pod
const VAULT_ALLOCATOR_ADDRESS =
  "0x7347602aedf0197492a6d10f7e9d9dda45493e62b26bd540e980617e92b4e38";

// Owner address that can manage the pod
const OWNER_ADDRESS = owner.address;

// Authorized caller address that can transfer assets
const AUTHORIZED_CALLER_ADDRESS =
  "0x0725F4506F4459E816164a3aA22660A47E8fD91aa4284416592541bC100E254A";

// ============================================
// END OF PARAMETERS
// ============================================

export async function deployAssetTransferPod(envNetwork: string) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];

  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const classHash = networkConfig.hash?.AssetTransferPod;
  if (!classHash) {
    throw new Error(
      `AssetTransferPod class hash not found for network: ${envNetwork}. Please declare the contract first.`
    );
  }

  // Validate parameters
  if (!VAULT_ALLOCATOR_ADDRESS) {
    throw new Error("VAULT_ALLOCATOR_ADDRESS is required");
  }
  if (!OWNER_ADDRESS) {
    throw new Error("OWNER_ADDRESS is required");
  }
  if (!AUTHORIZED_CALLER_ADDRESS) {
    throw new Error("AUTHORIZED_CALLER_ADDRESS is required");
  }

  try {
    console.log(`Deploying AssetTransferPod with constructor params:`);
    console.log(`  Vault Allocator: ${VAULT_ALLOCATOR_ADDRESS}`);
    console.log(`  Owner: ${OWNER_ADDRESS}`);
    console.log(`  Authorized Caller: ${AUTHORIZED_CALLER_ADDRESS}`);

    // Construct calldata matching constructor order:
    // vault_allocator, owner, authorized_caller
    const constructorCalldata = CallData.compile({
      vault_allocator: VAULT_ALLOCATOR_ADDRESS,
      owner: OWNER_ADDRESS,
      authorized_caller: AUTHORIZED_CALLER_ADDRESS,
    });

    const deployResponse = await owner.deployContract({
      classHash: classHash,
      constructorCalldata: constructorCalldata,
    });

    console.log(`\nAssetTransferPod deployed successfully!`);
    console.log(`Contract Address: ${deployResponse.contract_address}`);
    console.log(`Transaction Hash: ${deployResponse.transaction_hash}`);

    return deployResponse.contract_address;
  } catch (error) {
    console.error("Error deploying AssetTransferPod:", error);
    throw error;
  }
}

async function main() {
  try {
    const envNetwork = await getNetworkEnv(provider);

    console.log("Initializing AssetTransferPod deployment process...\n");

    console.log("\nDeployment Summary:");
    console.log(`Network: ${envNetwork}`);
    console.log(`Deployer: ${owner.address}`);

    const confirm = await askQuestion(
      "\nDo you want to proceed with deployment? (yes/no): "
    );
    if (confirm.toLowerCase() !== "yes") {
      console.log("Deployment cancelled.");
      rl.close();
      return;
    }

    console.log("\nDeploying AssetTransferPod...");
    const podAddress = await deployAssetTransferPod(envNetwork);

    const saveName = await askQuestion(
      "\nEnter a name to save this deployment (leave empty to skip): "
    );
    if (saveName) {
      saveContractDeployment(envNetwork, saveName, podAddress, "deployed");
      console.log(`Deployment saved as: ${saveName}`);
    }

    console.log("\nDeployment completed successfully!");
    console.log(`AssetTransferPod Address: ${podAddress}`);
  } catch (error) {
    console.error("\nDeployment failed:", error);
    throw error;
  } finally {
    rl.close();
  }
}

main().catch(console.error);
