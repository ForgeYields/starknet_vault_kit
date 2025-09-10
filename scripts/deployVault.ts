import {
  Account,
  byteArray,
  CairoUint256,
  CallData,
  RpcProvider,
  validateAndParseAddress,
} from "starknet";
import dotenv from "dotenv";
import { readConfigs } from "./configs/utils";
import { getNetworkEnv, WAD } from "./utils";
import { saveVaultDeployment } from "./utils/deployment";
import { Decimal } from "decimal.js";
import readline from "readline";

interface VaultDeploymentConfig {
  name: string;
  symbol: string;
  underlyingAsset: string;
  ownerAddress: string;
  feesRecipient: string;
  redeemFeesPercentage: string;
  performanceFeePercentage: string;
  managementFeePercentage: string;
  reportDelay: string;
  maxDeltaPercentage: string;
}

interface VaultAllocatorDeploymentConfig {
  vault: string;
  manager: string;
  paymentToken: string;
}

interface DeploymentConfig {
  vault?: VaultDeploymentConfig;
  vaultAllocator?: VaultAllocatorDeploymentConfig;
}

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

const MAX_REDEEM_FEE_PERCENT = 0.1;
const MAX_MANAGEMENT_FEE_PERCENT = 2.0;
const MAX_PERFORMANCE_FEE_PERCENT = 20.0;
const MIN_REPORT_DELAY_SECONDS = 3600;

function validatePercentage(value: string, fieldName: string): void {
  const num = parseFloat(value);
  if (isNaN(num) || num < 0) {
    throw new Error(`${fieldName} must be a valid non-negative percentage`);
  }
}

function validateRedeemFeePercentage(value: string): void {
  const num = parseFloat(value);
  validatePercentage(value, "Redeem fees percentage");
  if (num > MAX_REDEEM_FEE_PERCENT) {
    throw new Error(
      `Redeem fees percentage must not exceed ${MAX_REDEEM_FEE_PERCENT}% (vault contract limit)`
    );
  }
}

function validateManagementFeePercentage(value: string): void {
  const num = parseFloat(value);
  validatePercentage(value, "Management fees percentage");
  if (num > MAX_MANAGEMENT_FEE_PERCENT) {
    throw new Error(
      `Management fees percentage must not exceed ${MAX_MANAGEMENT_FEE_PERCENT}% (vault contract limit)`
    );
  }
}

function validatePerformanceFeePercentage(value: string): void {
  const num = parseFloat(value);
  validatePercentage(value, "Performance fees percentage");
  if (num > MAX_PERFORMANCE_FEE_PERCENT) {
    throw new Error(
      `Performance fees percentage must not exceed ${MAX_PERFORMANCE_FEE_PERCENT}% (vault contract limit)`
    );
  }
}

function validateReportDelay(value: string): void {
  const num = parseInt(value);
  if (isNaN(num) || num < MIN_REPORT_DELAY_SECONDS) {
    throw new Error(
      `Report delay must be at least ${MIN_REPORT_DELAY_SECONDS} seconds (1 hour minimum from vault contract)`
    );
  }
}

function validateMaxDeltaPercentage(value: string): void {
  const num = parseFloat(value);
  if (isNaN(num) || num < 0 || num > 100) {
    throw new Error("Max delta percentage must be between 0 and 100");
  }
}

async function collectVaultParameters(): Promise<VaultDeploymentConfig> {
  console.log("🚀 Initializing vault deployment process...\n");
  console.log("Please provide the following parameters:\n");

  const name = await askQuestion("Vault name: ");
  const symbol = await askQuestion("Vault symbol: ");

  const underlyingAsset = await askQuestion("Underlying asset address: ");
  try {
    validateAndParseAddress(underlyingAsset);
  } catch (error) {
    throw new Error(`Invalid underlying asset address: ${underlyingAsset}`);
  }

  const ownerAddress = owner.address;

  const feesRecipient = await askQuestion("Fees recipient address: ");
  try {
    validateAndParseAddress(feesRecipient);
  } catch (error) {
    throw new Error(`Invalid fees recipient address: ${feesRecipient}`);
  }

  const redeemFeesPercentage = await askQuestion("Redeem fees percentage: ");
  validateRedeemFeePercentage(redeemFeesPercentage);

  const performanceFeePercentage = await askQuestion(
    "Performance fee percentage: "
  );
  validatePerformanceFeePercentage(performanceFeePercentage);

  const managementFeePercentage = await askQuestion(
    "Management fee percentage: "
  );
  validateManagementFeePercentage(managementFeePercentage);

  const reportDelay = await askQuestion("Report delay (seconds): ");
  validateReportDelay(reportDelay);

  const maxDeltaPercentage = await askQuestion("Max delta percentage: ");
  validateMaxDeltaPercentage(maxDeltaPercentage);

  return {
    name,
    symbol,
    underlyingAsset,
    ownerAddress,
    feesRecipient,
    redeemFeesPercentage,
    performanceFeePercentage,
    managementFeePercentage,
    reportDelay,
    maxDeltaPercentage,
  };
}

async function askCustodialType(): Promise<{
  isCustodial: boolean;
  vaultAllocatorAddress?: string;
}> {
  const custodialAnswer = await askQuestion(
    "\nIs this vault custodial? (y/n): "
  );

  const normalizedAnswer = custodialAnswer.toLowerCase().trim();
  if (!["y", "yes", "n", "no"].includes(normalizedAnswer)) {
    throw new Error(
      `Invalid custodial type answer: '${custodialAnswer}'. Please enter 'y', 'yes', 'n', or 'no'.`
    );
  }

  const isCustodial = normalizedAnswer === "y" || normalizedAnswer === "yes";

  if (isCustodial) {
    const vaultAllocatorAddress = await askQuestion(
      "Vault allocator address: "
    );

    try {
      validateAndParseAddress(vaultAllocatorAddress);
    } catch (error) {
      throw new Error(
        `Invalid vault allocator address: ${vaultAllocatorAddress}`
      );
    }

    return { isCustodial, vaultAllocatorAddress };
  }

  return { isCustodial };
}

export async function deployVault(
  envNetwork: string,
  nameString: string,
  symbolString: string,
  underlyingAsset: string,
  ownerAddress: string,
  feesRecipient: string,
  redeemFeesPercentage: string,
  performanceFeePercentage: string,
  managementFeePercentage: string,
  reportDelay: string,
  maxDeltaPercentage: string
) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];

  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const classHash = networkConfig.hash?.Vault;
  if (!classHash) {
    throw new Error(
      `Vault class hash not found for network: ${envNetwork}. Please declare the contract first.`
    );
  }

  const redeemFees = new CairoUint256(
    new Decimal(redeemFeesPercentage).mul(WAD).div(100).toString()
  );

  const managementFees = new CairoUint256(
    new Decimal(managementFeePercentage).mul(WAD).div(100).toString()
  );

  const performanceFees = new CairoUint256(
    new Decimal(performanceFeePercentage).mul(WAD).div(100).toString()
  );

  const maxDelta = new CairoUint256(
    new Decimal(maxDeltaPercentage).mul(WAD).div(100).toString()
  );

  const nameBytes = byteArray.byteArrayFromString(nameString);
  const symbolBytes = byteArray.byteArrayFromString(symbolString);

  try {
    let constructorCalldata = {
      name: nameBytes,
      symbol: symbolBytes,
      underlying_asset: underlyingAsset,
      owner: ownerAddress,
      fees_recipient: feesRecipient,
      redeem_fees: redeemFees,
      management_fees: managementFees,
      performance_fees: performanceFees,
      report_delay: reportDelay,
      max_delta: maxDelta,
    };

    console.log(constructorCalldata);

    console.log(`Deploying Vault with constructor params:`);
    console.log(`  Name: ${nameString}`);
    console.log(`  Symbol: ${symbolString}`);
    console.log(`  Asset: ${underlyingAsset}`);
    console.log(`  Owner: ${ownerAddress}`);
    console.log(`  Fees Recipient: ${feesRecipient}`);
    console.log(`  Redeem Fees: ${redeemFeesPercentage}`);
    console.log(`  Performance Fee: ${performanceFeePercentage}`);
    console.log(`  Management Fee: ${managementFeePercentage}`);
    console.log(`  Report Delay: ${reportDelay}`);
    console.log(`  Max Delta: ${maxDeltaPercentage}`);

    const deployResponse = await owner.deployContract({
      classHash: classHash,
      constructorCalldata: constructorCalldata,
    });

    console.log(`Vault deployed successfully!`);
    console.log(`Contract Address: ${deployResponse.contract_address}`);
    console.log(`Transaction Hash: ${deployResponse.transaction_hash}`);

    saveVaultDeployment(
      envNetwork,
      symbolString,
      "vault",
      deployResponse.contract_address,
      deployResponse.transaction_hash
    );

    return deployResponse.contract_address;
  } catch (error) {
    console.error("Error deploying Vault:", error);
    throw error;
  }
}

export async function deployRedeemRequest(
  envNetwork: string,
  ownerAddress: string,
  vaultAddress: string,
  vaultSymbol?: string
) {
  const config = readConfigs();
  const networkConfig = config[envNetwork];

  if (!networkConfig) {
    throw new Error(`Configuration not found for network: ${envNetwork}`);
  }

  const classHash = networkConfig.hash?.RedeemRequest;
  if (!classHash) {
    throw new Error(
      `RedeemRequest class hash not found for network: ${envNetwork}. Please declare the contract first.`
    );
  }

  try {
    console.log(`Deploying RedeemRequest with constructor params:`);
    console.log(`  Owner: ${owner.address}`);
    console.log(`  Vault: ${vaultAddress}`);

    const deployResponse = await owner.deployContract({
      classHash: classHash,
      constructorCalldata: [owner.address, vaultAddress],
    });

    console.log(`RedeemRequest deployed successfully!`);
    console.log(`Contract Address: ${deployResponse.contract_address}`);
    console.log(`Transaction Hash: ${deployResponse.transaction_hash}`);

    if (vaultSymbol) {
      saveVaultDeployment(
        envNetwork,
        vaultSymbol,
        "redeemRequest",
        deployResponse.contract_address,
        deployResponse.transaction_hash
      );
    }

    return deployResponse.contract_address;
  } catch (error) {
    console.error("Error deploying RedeemRequest:", error);
    throw error;
  }
}

export async function linkRedeemRequestToVault(
  vaultAddress: string,
  redeemRequestAddress: string
) {
  try {
    console.log(`Linking RedeemRequest to Vault...`);
    console.log(`  Vault: ${vaultAddress}`);
    console.log(`  RedeemRequest: ${redeemRequestAddress}`);

    const response = await owner.execute({
      contractAddress: vaultAddress,
      entrypoint: "register_redeem_request",
      calldata: [redeemRequestAddress],
    });

    console.log(`RedeemRequest linked to Vault successfully!`);
    console.log(`Transaction Hash: ${response.transaction_hash}`);

    return response.transaction_hash;
  } catch (error) {
    console.error("Error linking RedeemRequest to Vault:", error);
    throw error;
  }
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

  const vesuSingleton = networkConfig.periphery?.vesuSingleton;
  if (!vesuSingleton) {
    throw new Error(
      `Vesu Singleton address not found for network: ${envNetwork}.`
    );
  }

  try {
    const constructorCalldata = CallData.compile([
      owner.address,
      vaultAllocatorAddress,
      vesuSingleton,
    ]);

    console.log(`Deploying Manager with constructor params:`);
    console.log(`  Owner: ${owner.address}`);
    console.log(`  Vault Allocator: ${vaultAllocatorAddress}`);
    console.log(`  Vesu Singleton: ${vesuSingleton}`);

    const deployResponse = await owner.deployContract({
      classHash: classHash,
      constructorCalldata: constructorCalldata,
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

export async function attachVaultAllocatorToVault(
  vaultAddress: string,
  vaultAllocatorAddress: string
) {
  try {
    console.log(`Attaching VaultAllocator to Vault...`);
    console.log(`  Vault: ${vaultAddress}`);
    console.log(`  VaultAllocator: ${vaultAllocatorAddress}`);

    const response = await owner.execute({
      contractAddress: vaultAddress,
      entrypoint: "register_vault_allocator",
      calldata: [vaultAllocatorAddress],
    });

    console.log(`VaultAllocator attached to Vault successfully!`);
    console.log(`Transaction Hash: ${response.transaction_hash}`);

    return response.transaction_hash;
  } catch (error) {
    console.error("Error attaching VaultAllocator to Vault:", error);
    throw error;
  }
}

export async function setManagerInVaultAllocator(
  vaultAllocatorAddress: string,
  managerAddress: string
) {
  try {
    console.log(`Setting Manager in VaultAllocator...`);
    console.log(`  VaultAllocator: ${vaultAllocatorAddress}`);
    console.log(`  Manager: ${managerAddress}`);

    const response = await owner.execute({
      contractAddress: vaultAllocatorAddress,
      entrypoint: "set_manager",
      calldata: [managerAddress],
    });

    console.log(`Manager set in VaultAllocator successfully!`);
    console.log(`Transaction Hash: ${response.transaction_hash}`);

    return response.transaction_hash;
  } catch (error) {
    console.error("Error setting Manager in VaultAllocator:", error);
    throw error;
  }
}

async function main() {
  try {
    const envNetwork = await getNetworkEnv(provider);

    const vaultConfig = await collectVaultParameters();

    const { isCustodial, vaultAllocatorAddress } = await askCustodialType();

    console.log("\n📋 Deployment Summary:");
    console.log(`Network: ${envNetwork}`);
    console.log(`Vault Type: ${isCustodial ? "Custodial" : "Non-custodial"}`);
    if (isCustodial) {
      console.log(`Vault Allocator: ${vaultAllocatorAddress}`);
    }
    console.log("\n🚀 Starting deployment process...\n");

    console.log("📦 Deploying Vault...");
    const vaultAddress = await deployVault(
      envNetwork,
      vaultConfig.name,
      vaultConfig.symbol,
      vaultConfig.underlyingAsset,
      vaultConfig.ownerAddress,
      vaultConfig.feesRecipient,
      vaultConfig.redeemFeesPercentage,
      vaultConfig.performanceFeePercentage,
      vaultConfig.managementFeePercentage,
      vaultConfig.reportDelay,
      vaultConfig.maxDeltaPercentage
    );
    console.log("\n⏳ Waiting 3 seconds before deploying RedeemRequest...");
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    console.log("\n📦 Deploying RedeemRequest...");
    const redeemRequestAddress = await deployRedeemRequest(
      envNetwork,
      vaultConfig.ownerAddress,
      vaultAddress,
      vaultConfig.symbol
    );

    console.log("\n⏳ Waiting 3 seconds before linking RedeemRequest to Vault...");
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    console.log("\n🔗 Linking RedeemRequest to Vault...");
    await linkRedeemRequestToVault(vaultAddress, redeemRequestAddress);

    console.log("\n⏳ Waiting 3 seconds before vault allocator operations...");
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    if (isCustodial) {
      console.log("\n🔗 Attaching existing VaultAllocator to Vault...");
      await attachVaultAllocatorToVault(vaultAddress, vaultAllocatorAddress!);
    } else {
      console.log("\n📦 Deploying new VaultAllocator...");

      const newVaultAllocatorAddress = await deployVaultAllocator(
        envNetwork,
        vaultConfig.symbol
      );

      console.log("\n⏳ Waiting 3 seconds before attaching VaultAllocator to Vault...");
      await new Promise(resolve => setTimeout(resolve, 3000));

      console.log("\n🔗 Attaching new VaultAllocator to Vault...");
      await attachVaultAllocatorToVault(vaultAddress, newVaultAllocatorAddress);

      console.log("\n⏳ Waiting 3 seconds before deploying Manager...");
      await new Promise(resolve => setTimeout(resolve, 3000));

      console.log("\n📦 Deploying Manager...");
      const managerAddress = await deployManager(
        envNetwork,
        newVaultAllocatorAddress,
        vaultConfig.symbol
      );

      console.log("\n⏳ Waiting 3 seconds before setting Manager in VaultAllocator...");
      await new Promise(resolve => setTimeout(resolve, 3000));

      console.log("\n🔗 Setting Manager in VaultAllocator...");
      await setManagerInVaultAllocator(
        newVaultAllocatorAddress,
        managerAddress
      );
    }

    console.log("\n✅ Deployment completed successfully!");
    console.log(`📍 Vault Address: ${vaultAddress}`);
    console.log(`📍 RedeemRequest Address: ${redeemRequestAddress}`);
  } catch (error) {
    console.error("\n❌ Deployment failed:", error);
    throw error;
  } finally {
    rl.close();
  }
}

main().catch(console.error);
