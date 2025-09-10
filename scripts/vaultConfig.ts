import {
  Account,
  CairoUint256,
  RpcProvider,
  validateAndParseAddress,
  hash,
} from "starknet";
import dotenv from "dotenv";
import { getNetworkEnv, WAD } from "./utils";
import { Decimal } from "decimal.js";
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
      `Redeem fees percentage must not exceed ${MAX_REDEEM_FEE_PERCENT}%`
    );
  }
}

function validateManagementFeePercentage(value: string): void {
  const num = parseFloat(value);
  validatePercentage(value, "Management fees percentage");
  if (num > MAX_MANAGEMENT_FEE_PERCENT) {
    throw new Error(
      `Management fees percentage must not exceed ${MAX_MANAGEMENT_FEE_PERCENT}%`
    );
  }
}

function validatePerformanceFeePercentage(value: string): void {
  const num = parseFloat(value);
  validatePercentage(value, "Performance fees percentage");
  if (num > MAX_PERFORMANCE_FEE_PERCENT) {
    throw new Error(
      `Performance fees percentage must not exceed ${MAX_PERFORMANCE_FEE_PERCENT}%`
    );
  }
}

function validateReportDelay(value: string): void {
  const num = parseInt(value);
  if (isNaN(num) || num < MIN_REPORT_DELAY_SECONDS) {
    throw new Error(
      `Report delay must be at least ${MIN_REPORT_DELAY_SECONDS} seconds (1 hour minimum)`
    );
  }
}

function validateMaxDeltaPercentage(value: string): void {
  const num = parseFloat(value);
  if (isNaN(num) || num < 0 || num > 100) {
    throw new Error("Max delta percentage must be between 0 and 100");
  }
}

async function getVaultAddress(): Promise<string> {
  const vaultAddress = await askQuestion("Enter vault contract address: ");
  try {
    validateAndParseAddress(vaultAddress);
    return vaultAddress;
  } catch (error) {
    throw new Error(`Invalid vault address: ${vaultAddress}`);
  }
}

async function showConfigMenu(): Promise<string> {
  console.log("\n📋 Vault Configuration Options:");
  console.log("1. Set Fees Configuration");
  console.log("2. Set Report Delay");
  console.log("3. Set Max Delta");
  console.log("4. Grant Oracle Role");
  console.log("5. Exit");

  const choice = await askQuestion("\nSelect an option (1-5): ");
  return choice.trim();
}

async function setFeesConfig(vaultAddress: string): Promise<void> {
  console.log("\n💰 Set Fees Configuration");
  console.log(`  - Redeem fees: max ${MAX_REDEEM_FEE_PERCENT}%`);
  console.log(`  - Management fees: max ${MAX_MANAGEMENT_FEE_PERCENT}%`);
  console.log(`  - Performance fees: max ${MAX_PERFORMANCE_FEE_PERCENT}%`);
  console.log();

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

  const redeemFees = new CairoUint256(
    new Decimal(redeemFeesPercentage).mul(WAD).div(100).toString()
  );

  const managementFees = new CairoUint256(
    new Decimal(managementFeePercentage).mul(WAD).div(100).toString()
  );

  const performanceFees = new CairoUint256(
    new Decimal(performanceFeePercentage).mul(WAD).div(100).toString()
  );

  console.log(`\n📋 Configuration Summary:`);
  console.log(`  Vault: ${vaultAddress}`);
  console.log(`  Fees Recipient: ${feesRecipient}`);
  console.log(`  Redeem Fees: ${redeemFeesPercentage}%`);
  console.log(`  Management Fees: ${managementFeePercentage}%`);
  console.log(`  Performance Fees: ${performanceFeePercentage}%`);

  const confirm = await askQuestion("\nConfirm configuration? (y/n): ");
  if (confirm.toLowerCase() !== "y" && confirm.toLowerCase() !== "yes") {
    console.log("Configuration cancelled.");
    return;
  }

  try {
    const response = await owner.execute({
      contractAddress: vaultAddress,
      entrypoint: "set_fees_config",
      calldata: [feesRecipient, redeemFees, managementFees, performanceFees],
    });

    console.log("✅ Fees configuration updated successfully!");
    console.log(`Transaction Hash: ${response.transaction_hash}`);
  } catch (error) {
    console.error("❌ Error setting fees configuration:", error);
    throw error;
  }
}

async function setReportDelay(vaultAddress: string): Promise<void> {
  console.log("\n⏰ Set Report Delay");
  console.log(`Minimum delay: ${MIN_REPORT_DELAY_SECONDS} seconds (1 hour)`);

  const reportDelay = await askQuestion("Report delay (seconds): ");
  validateReportDelay(reportDelay);

  console.log(`\n📋 Configuration Summary:`);
  console.log(`  Vault: ${vaultAddress}`);
  console.log(
    `  Report Delay: ${reportDelay} seconds (${Math.floor(
      parseInt(reportDelay) / 3600
    )} hours)`
  );

  const confirm = await askQuestion("\nConfirm configuration? (y/n): ");
  if (confirm.toLowerCase() !== "y" && confirm.toLowerCase() !== "yes") {
    console.log("Configuration cancelled.");
    return;
  }

  try {
    const response = await owner.execute({
      contractAddress: vaultAddress,
      entrypoint: "set_report_delay",
      calldata: [reportDelay],
    });

    console.log("✅ Report delay updated successfully!");
    console.log(`Transaction Hash: ${response.transaction_hash}`);
  } catch (error) {
    console.error("❌ Error setting report delay:", error);
    throw error;
  }
}

async function setMaxDelta(vaultAddress: string): Promise<void> {
  console.log("\n📊 Set Max Delta");
  console.log("Max delta percentage range: 0-100%");

  const maxDeltaPercentage = await askQuestion("Max delta percentage: ");
  validateMaxDeltaPercentage(maxDeltaPercentage);

  const maxDelta = new CairoUint256(
    new Decimal(maxDeltaPercentage).mul(WAD).div(100).toString()
  );

  console.log(`\n📋 Configuration Summary:`);
  console.log(`  Vault: ${vaultAddress}`);
  console.log(`  Max Delta: ${maxDeltaPercentage}%`);

  const confirm = await askQuestion("\nConfirm configuration? (y/n): ");
  if (confirm.toLowerCase() !== "y" && confirm.toLowerCase() !== "yes") {
    console.log("Configuration cancelled.");
    return;
  }

  try {
    const response = await owner.execute({
      contractAddress: vaultAddress,
      entrypoint: "set_max_delta",
      calldata: [maxDelta],
    });

    console.log("✅ Max delta updated successfully!");
    console.log(`Transaction Hash: ${response.transaction_hash}`);
  } catch (error) {
    console.error("❌ Error setting max delta:", error);
    throw error;
  }
}

async function grantOracleRole(vaultAddress: string): Promise<void> {
  console.log("\n🔮 Grant Oracle Role");
  console.log("This will grant the ORACLE_ROLE to a specified account.");

  const oracleAccount = await askQuestion("Oracle account address: ");
  try {
    validateAndParseAddress(oracleAccount);
  } catch (error) {
    throw new Error(`Invalid oracle account address: ${oracleAccount}`);
  }

  console.log(`\n📋 Configuration Summary:`);
  console.log(`  Vault: ${vaultAddress}`);
  console.log(`  Oracle Account: ${oracleAccount}`);
  console.log(`  Role: ORACLE_ROLE`);

  const confirm = await askQuestion("\nConfirm granting oracle role? (y/n): ");
  if (confirm.toLowerCase() !== "y" && confirm.toLowerCase() !== "yes") {
    console.log("Operation cancelled.");
    return;
  }

  try {
    const response = await owner.execute({
      contractAddress: vaultAddress,
      entrypoint: "grant_role",
      calldata: [hash.starknetKeccak("ORACLE_ROLE").toString(), oracleAccount],
    });

    console.log("✅ Oracle role granted successfully!");
    console.log(`Transaction Hash: ${response.transaction_hash}`);
  } catch (error) {
    console.error("❌ Error granting oracle role:", error);
    throw error;
  }
}

async function main() {
  try {
    const envNetwork = await getNetworkEnv(provider);
    console.log(`🌐 Connected to network: ${envNetwork}`);
    console.log(`👤 Using account: ${owner.address}`);

    const vaultAddress = await getVaultAddress();

    while (true) {
      const choice = await showConfigMenu();

      switch (choice) {
        case "1":
          await setFeesConfig(vaultAddress);
          break;

        case "2":
          await setReportDelay(vaultAddress);
          break;

        case "3":
          await setMaxDelta(vaultAddress);
          break;

        case "4":
          await grantOracleRole(vaultAddress);
          break;

        case "5":
          console.log("👋 Goodbye!");
          return;

        default:
          console.log("❌ Invalid choice. Please select 1-5.");
          break;
      }

      console.log("\n" + "=".repeat(50));
    }
  } catch (error) {
    console.error("\n❌ Configuration failed:", error);
    throw error;
  } finally {
    rl.close();
  }
}

main().catch(console.error);
