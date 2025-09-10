import { Account, json, RpcProvider, hash } from "starknet";
import fs from "fs";
import dotenv from "dotenv";
import { readConfigs, writeConfigs } from "./configs/utils";
import { getNetworkEnv } from "./utils";

dotenv.config({ path: __dirname + "/../.env" });

const provider = new RpcProvider({ nodeUrl: process.env.RPC });

const owner = new Account(
  provider,
  process.env.ACCOUNT_ADDRESS as string,
  process.env.ACCOUNT_PK as string,
  undefined,
  "0x3"
);

export async function declareContract(
  envNetwork: string,
  packageName: string,
  name: string
) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];
  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const compiledContract = await json.parse(
    fs
      .readFileSync(`../target/dev/${packageName}_${name}.contract_class.json`)
      .toString("ascii")
  );
  const compiledSierraCasm = await json.parse(
    fs
      .readFileSync(
        `../target/dev/${packageName}_${name}.compiled_contract_class.json`
      )
      .toString("ascii")
  );

  try {
    const declareResponse = await owner.declare({
      contract: compiledContract,
      casm: compiledSierraCasm,
    });

    let classHash = declareResponse.class_hash;
    console.log(
      `Class Hash ${name}: ${classHash} deployed for network: ${envNetwork}`
    );
    if (!networkConfig.hash) {
      networkConfig.hash = {};
    }
    networkConfig.hash[name] = classHash;
    config[envNetwork] = networkConfig;
    writeConfigs(config);
  } catch (error) {
    console.error(error);
  }
}

async function main() {
  if (!process.argv[2] || !process.argv[3]) {
    throw new Error("Missing --contract <contract_name>");
  }

  let envNetwork = await getNetworkEnv(provider);
  switch (process.argv[3]) {
    case "Vault":
      await declareContract(envNetwork, "vault", "Vault");
      break;
    case "VaultAllocator":
      await declareContract(envNetwork, "vault_allocator", "VaultAllocator");
      break;
    case "RedeemRequest":
      await declareContract(envNetwork, "vault", "RedeemRequest");
      break;
    case "AvnuMiddleware":
      await declareContract(envNetwork, "vault_allocator", "AvnuMiddleware");
      break;
    case "Manager":
      await declareContract(envNetwork, "vault_allocator", "Manager");
      break;
    case "PriceRouter":
      await declareContract(envNetwork, "vault_allocator", "PriceRouter");
      break;
    case "SimpleDecoderAndSanitizer":
      await declareContract(
        envNetwork,
        "vault_allocator",
        "SimpleDecoderAndSanitizer"
      );
      break;
    case "AumProvider4626":
      await declareContract(envNetwork, "vault", "AumProvider4626");
      break;
    default:
      throw new Error("Error: Unknown contract");
  }
}

main();
