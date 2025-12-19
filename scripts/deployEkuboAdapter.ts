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

// Vault allocator address that will control this adapter
const VAULT_ALLOCATOR_ADDRESS =
  "0x7347602aedf0197492a6d10f7e9d9dda45493e62b26bd540e980617e92b4e38";

// Ekubo positions contract address
const EKUBO_POSITIONS_CONTRACT =
  "0x02e0af29598b407c8716b17f6d2795eca1b471413fa03fb145a5e33722184067";

// Ekubo positions NFT contract address
const EKUBO_POSITIONS_NFT =
  "0x07b696af58c967c1b14c9dde0ace001720635a660a8e90c565ea459345318b30";

// Ekubo core contract address
const EKUBO_CORE =
  "0x00000005dd3D2F4429AF886cD1a3b08289DBcEa99A294197E9eB43b0e0325b4b";

// Pool key parameters
const POOL_KEY = {
  token0: "0x03Fe2b97C1Fd336E750087D68B9b867997Fd64a2661fF3ca5A7C771641e8e7AC", // Lower address token
  token1: "0x0593e034DdA23eea82d2bA9a30960ED42CF4A01502Cc2351Dc9B9881F9931a68", // Higher address token
  fee: "0x0", // Fee tier (e.g., "170141183460469235273462165868118016")
  tick_spacing: "100", // Tick spacing (e.g., "1000")
  extension: "0x0", // Extension address (usually 0)
};

// Bounds settings for the position
// i129 is represented as { mag: u128, sign: bool } where sign=true means negative
const BOUNDS_SETTINGS = {
  lower: {
    mag: "23025400", // Magnitude of lower tick
    sign: false, //
  },
  upper: {
    mag: "23026200", // Magnitude of upper tick
    sign: false, //
  },
};

// ============================================
// END OF PARAMETERS
// ============================================

export async function deployEkuboAdapter(envNetwork: string) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];

  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const classHash = networkConfig.hash?.EkuboAdapter;
  if (!classHash) {
    throw new Error(
      `EkuboAdapter class hash not found for network: ${envNetwork}. Please declare the contract first.`
    );
  }

  // Validate parameters
  if (!VAULT_ALLOCATOR_ADDRESS) {
    throw new Error("VAULT_ALLOCATOR_ADDRESS is required");
  }
  if (!EKUBO_POSITIONS_CONTRACT) {
    throw new Error("EKUBO_POSITIONS_CONTRACT is required");
  }
  if (!EKUBO_POSITIONS_NFT) {
    throw new Error("EKUBO_POSITIONS_NFT is required");
  }
  if (!EKUBO_CORE) {
    throw new Error("EKUBO_CORE is required");
  }
  if (!POOL_KEY.token0 || !POOL_KEY.token1) {
    throw new Error("POOL_KEY tokens are required");
  }
  if (!POOL_KEY.fee) {
    throw new Error("POOL_KEY fee is required");
  }
  if (!POOL_KEY.tick_spacing) {
    throw new Error("POOL_KEY tick_spacing is required");
  }
  if (!BOUNDS_SETTINGS.lower.mag || !BOUNDS_SETTINGS.upper.mag) {
    throw new Error("BOUNDS_SETTINGS magnitudes are required");
  }

  try {
    console.log(`Deploying EkuboAdapter with constructor params:`);
    console.log(`  Vault Allocator: ${VAULT_ALLOCATOR_ADDRESS}`);
    console.log(`  Ekubo Positions Contract: ${EKUBO_POSITIONS_CONTRACT}`);
    console.log(`  Ekubo Positions NFT: ${EKUBO_POSITIONS_NFT}`);
    console.log(`  Ekubo Core: ${EKUBO_CORE}`);
    console.log(`  Pool Key:`);
    console.log(`    Token0: ${POOL_KEY.token0}`);
    console.log(`    Token1: ${POOL_KEY.token1}`);
    console.log(`    Fee: ${POOL_KEY.fee}`);
    console.log(`    Tick Spacing: ${POOL_KEY.tick_spacing}`);
    console.log(`    Extension: ${POOL_KEY.extension}`);
    console.log(`  Bounds Settings:`);
    console.log(
      `    Lower: ${BOUNDS_SETTINGS.lower.sign ? "-" : ""}${
        BOUNDS_SETTINGS.lower.mag
      }`
    );
    console.log(
      `    Upper: ${BOUNDS_SETTINGS.upper.sign ? "-" : ""}${
        BOUNDS_SETTINGS.upper.mag
      }`
    );

    // Construct calldata
    // Constructor order: vault_allocator, ekubo_positions_contract, bounds_settings, pool_key, ekubo_positions_nft, ekubo_core
    const constructorCalldata = CallData.compile({
      vault_allocator: VAULT_ALLOCATOR_ADDRESS,
      ekubo_positions_contract: EKUBO_POSITIONS_CONTRACT,
      bounds_settings: {
        lower: {
          mag: BOUNDS_SETTINGS.lower.mag,
          sign: BOUNDS_SETTINGS.lower.sign,
        },
        upper: {
          mag: BOUNDS_SETTINGS.upper.mag,
          sign: BOUNDS_SETTINGS.upper.sign,
        },
      },
      pool_key: {
        token0: POOL_KEY.token0,
        token1: POOL_KEY.token1,
        fee: POOL_KEY.fee,
        tick_spacing: POOL_KEY.tick_spacing,
        extension: POOL_KEY.extension,
      },
      ekubo_positions_nft: EKUBO_POSITIONS_NFT,
      ekubo_core: EKUBO_CORE,
    });

    const deployResponse = await owner.deployContract({
      classHash: classHash,
      constructorCalldata: constructorCalldata,
    });

    console.log(`\nEkuboAdapter deployed successfully!`);
    console.log(`Contract Address: ${deployResponse.contract_address}`);
    console.log(`Transaction Hash: ${deployResponse.transaction_hash}`);

    return deployResponse.contract_address;
  } catch (error) {
    console.error("Error deploying EkuboAdapter:", error);
    throw error;
  }
}

async function main() {
  try {
    const envNetwork = await getNetworkEnv(provider);

    console.log("Initializing EkuboAdapter deployment process...\n");

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

    console.log("\nDeploying EkuboAdapter...");
    const ekuboAdapterAddress = await deployEkuboAdapter(envNetwork);

    const saveName = await askQuestion(
      "\nEnter a name to save this deployment (leave empty to skip): "
    );
    if (saveName) {
      saveContractDeployment(
        envNetwork,
        saveName,
        ekuboAdapterAddress,
        "deployed"
      );
      console.log(`Deployment saved as: ${saveName}`);
    }

    console.log("\nDeployment completed successfully!");
    console.log(`EkuboAdapter Address: ${ekuboAdapterAddress}`);
  } catch (error) {
    console.error("\nDeployment failed:", error);
    throw error;
  } finally {
    rl.close();
  }
}

main().catch(console.error);
