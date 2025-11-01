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

const chainIdToNetwork = {
  [constants.StarknetChainId.SN_SEPOLIA]: "sepolia",
  [constants.StarknetChainId.SN_MAIN]: "mainnet",
  ["0x505249564154455f534e5f50415241434c4541525f4d41494e4e4554"]:
    "paradex_prod",
  ["0x505249564154455f534e5f504f54435f5345504f4c4941"]: "paradex_testnet",
};
export async function getNetworkEnv(provider: RpcProvider): Promise<string> {
  const chainIdFromRpc = await provider.getChainId();
  if (chainIdToNetwork[chainIdFromRpc]) {
    return chainIdToNetwork[chainIdFromRpc];
  }
  throw new Error(`Unsupported network: ${chainIdFromRpc}`);
}

export const WAD = "1000000000000000000";
