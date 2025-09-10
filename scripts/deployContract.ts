import { Account, RpcProvider, CallData, CairoUint256 } from "starknet";
import dotenv from "dotenv";
import { readConfigs } from "./configs/utils";
import { getNetworkEnv } from "./utils";
import { saveContractDeployment } from "./utils/deployment";

dotenv.config({ path: __dirname + "/../.env" });

const provider = new RpcProvider({ nodeUrl: process.env.RPC });
const owner = new Account(
  provider,
  process.env.ACCOUNT_ADDRESS as string,
  process.env.ACCOUNT_PK as string,
  undefined,
  "0x3"
);

export async function deployContract(
  envNetwork: string,
  contractName: string,
  constructorParams?: any[]
) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];
  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const classHash = networkConfig.hash?.[contractName];
  if (!classHash) {
    throw new Error(
      `${contractName} class hash not found for network: ${envNetwork}. Please declare the contract first.`
    );
  }

  try {
    const constructorCalldata = constructorParams
      ? CallData.compile(constructorParams)
      : [];

    console.log(`Deploying ${contractName} with constructor params:`);
    if (constructorParams) {
      constructorParams.forEach((param, index) => {
        console.log(`  Param ${index}: ${param}`);
      });
    } else {
      console.log(`  No constructor parameters`);
    }

    const deployResponse = await owner.deployContract({
      classHash: classHash,
      constructorCalldata: constructorCalldata,
    });

    console.log(`${contractName} deployed successfully!`);
    console.log(`Contract Address: ${deployResponse.contract_address}`);
    console.log(`Transaction Hash: ${deployResponse.transaction_hash}`);

    saveContractDeployment(
      envNetwork,
      contractName,
      deployResponse.contract_address,
      deployResponse.transaction_hash
    );

    return deployResponse.contract_address;
  } catch (error) {
    console.error(`Error deploying ${contractName}:`, error);
    throw error;
  }
}

export async function deploySimpleDecoderAndSanitizer(envNetwork: string) {
  return await deployContract(envNetwork, "SimpleDecoderAndSanitizer", []);
}

export async function deployPriceRouter(envNetwork: string) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];
  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const pragmaAddress = networkConfig.periphery?.pragma;
  if (!pragmaAddress) {
    throw new Error(
      `pragma address not found for network: ${envNetwork}. Please add it to the config.`
    );
  }

  return await deployContract(envNetwork, "PriceRouter", [
    owner.address,
    pragmaAddress,
  ]);
}

export async function deployAvnuMiddleware(
  envNetwork: string,
  slippage_tolerance_bps: number
) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];
  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const avnuRouter = networkConfig.periphery?.avnuRouter;
  if (!avnuRouter) {
    throw new Error(
      `avnuRouter address not found for network: ${envNetwork}. Please add it to the config.`
    );
  }

  const priceRouter = networkConfig.pricerouter;
  if (!priceRouter) {
    throw new Error(
      `priceRouter address not found for network: ${envNetwork}. Please add it to the config.`
    );
  }

  const slippage_tolerance_bps_uint256 = new CairoUint256(
    slippage_tolerance_bps
  );

  return await deployContract(envNetwork, "AvnuMiddleware", [
    owner.address,
    avnuRouter,
    priceRouter,
    slippage_tolerance_bps_uint256,
  ]);
}

export async function deployAumProvider4626(
  envNetwork: string,
  vaultAddress: string,
  strategy4626Address: string
) {
  return await deployContract(envNetwork, "AumProvider4626", [
    vaultAddress,
    strategy4626Address,
  ]);
}

function validateSlippageTolerancePercentage(slippage: string): number {
  const num = parseFloat(slippage);
  if (isNaN(num) || num < 0 || num > 100) {
    throw new Error(
      `Invalid slippage tolerance: ${slippage}%. Must be between 0 and 100%`
    );
  }
  return Math.floor(num * 100);
}

function parseArguments(contractName: string, args: string[]) {
  switch (contractName) {
    case "SimpleDecoderAndSanitizer":
      return {};

    case "PriceRouter":
      return {};

    case "AvnuMiddleware":
      if (args.length < 1) {
        throw new Error(
          "AvnuMiddleware requires: <slippage_tolerance_percentage>"
        );
      }
      return {
        slippageToleranceBps: validateSlippageTolerancePercentage(args[0]),
      };

    case "AumProvider4626":
      if (args.length < 2) {
        throw new Error("AumProvider4626 requires: <vault_address>");
      }
      return {
        vaultAddress: args[0],
        strategy4626Address: args[1],
      };

    default:
      throw new Error(`Unknown contract: ${contractName}`);
  }
}

async function main() {
  try {
    const envNetwork = await getNetworkEnv(provider);

    if (!process.argv[2] || !process.argv[3]) {
      console.log(
        "Usage: npm run deploy:contract -- --contract <contract_name> [args...]"
      );
      console.log("\nAvailable contracts:");
      console.log("  - SimpleDecoderAndSanitizer");
      console.log("    Usage: --contract SimpleDecoderAndSanitizer");
      console.log("  - PriceRouter");
      console.log("    Usage: --contract PriceRouter");
      console.log("  - AvnuMiddleware <slippage_tolerance_percentage>");
      console.log(
        "    Usage: --contract AvnuMiddleware <slippage_tolerance_percentage>"
      );
      console.log(
        "    Note: slippage_tolerance_percentage should be between 0-100% (e.g., 2.5 for 2.5%)"
      );
      console.log("  - AumProvider4626 <vault_address> <strategy4626_address>");
      console.log(
        "    Usage: --contract AumProvider4626 <vault_address> <strategy4626_address>"
      );
      return;
    }

    const contractName = process.argv[3];
    const contractArgs = process.argv.slice(4);

    console.log(
      `\n🚀 Starting ${contractName} deployment on ${envNetwork}...\n`
    );

    const parsedArgs = parseArguments(contractName, contractArgs);
    let deployedAddress: string;

    switch (contractName) {
      case "SimpleDecoderAndSanitizer":
        deployedAddress = await deploySimpleDecoderAndSanitizer(envNetwork);
        break;

      case "PriceRouter":
        deployedAddress = await deployPriceRouter(envNetwork);
        break;

      case "AvnuMiddleware":
        deployedAddress = await deployAvnuMiddleware(
          envNetwork,
          parsedArgs.slippageToleranceBps as number
        );
        break;

      case "AumProvider4626":
        deployedAddress = await deployAumProvider4626(
          envNetwork,
          parsedArgs.vaultAddress as string,
          parsedArgs.strategy4626Address as string
        );
        break;

      default:
        throw new Error(`Unknown contract: ${contractName}`);
    }

    console.log(`\n✅ ${contractName} deployment completed successfully!`);
    console.log(`📍 Contract Address: ${deployedAddress}`);
    console.log(`🌐 Network: ${envNetwork}`);
  } catch (error) {
    console.error(`\n❌ Deployment failed:`, error);
    process.exit(1);
  }
}

main().catch(console.error);
