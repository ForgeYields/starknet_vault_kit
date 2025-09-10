import fs from "fs";
import dotenv from "dotenv";
import { RpcProvider, constants } from "starknet";

dotenv.config({ path: __dirname + "/../.env" });

export async function appendToEnv(name: string, address: string) {
  fs.appendFile(
    `${__dirname}/../.env`,
    `\n${name}_ADDRESS=${address}`,
    function (err) {
      if (err) throw err;
    }
  );
}

export async function getNetworkEnv(provider: RpcProvider): Promise<string> {
  const chainIdFromRpc = await provider.getChainId();
  if (chainIdFromRpc == constants.StarknetChainId.SN_SEPOLIA) {
    return "sepolia";
  }
  if (chainIdFromRpc == constants.StarknetChainId.SN_MAIN) {
    return "mainnet";
  }
  throw new Error(`Unsupported network: ${chainIdFromRpc}`);
}

export const WAD = "1000000000000000000";
