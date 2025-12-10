import { Account, RpcProvider, Contract } from "starknet";
import dotenv from "dotenv";
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

const VAULT_ALLOCATOR_ABI = [
  {
    type: "function",
    name: "set_manager",
    inputs: [
      {
        name: "manager",
        type: "core::starknet::contract_address::ContractAddress",
      },
    ],
    outputs: [],
    state_mutability: "external",
  },
];

async function setManager(
  vaultAllocatorAddress: string,
  newManagerAddress: string
) {
  const contract = new Contract(
    VAULT_ALLOCATOR_ABI,
    vaultAllocatorAddress,
    owner
  );

  console.log(`Setting manager on VaultAllocator: ${vaultAllocatorAddress}`);
  console.log(`New manager address: ${newManagerAddress}`);

  const tx = await contract.set_manager(newManagerAddress);
  console.log(`Transaction hash: ${tx.transaction_hash}`);

  await provider.waitForTransaction(tx.transaction_hash);
  console.log("Manager set successfully!");

  return tx.transaction_hash;
}

async function main() {
  const vaultAllocatorAddress = process.argv[2];
  const newManagerAddress = process.argv[3];

  if (!vaultAllocatorAddress || !newManagerAddress) {
    console.error(
      "Usage: npx tsx setManager.ts <vault_allocator_address> <new_manager_address>"
    );
    process.exit(1);
  }

  const envNetwork = await getNetworkEnv(provider);
  console.log(`Network: ${envNetwork}`);
  console.log(`Caller: ${owner.address}`);

  await setManager(vaultAllocatorAddress, newManagerAddress);
}

main().catch(console.error);
