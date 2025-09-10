/**
 * Example usage of VaultUserSDK
 * Demonstrates how to interact with the vault as a regular user
 */

import dotenv from "dotenv";
import { VaultUserSDK, VaultConfig } from "../src";
import { Account, RpcProvider } from "starknet";
import * as readline from "readline";

dotenv.config();

const vaultConfig: VaultConfig = {
  vaultAddress:
    "0x006ec49bb6bbd9262423e5948159f2a6fcd6ffb0a5a8492d2eff0ee13d020b6c",
};

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function question(query: string): Promise<string> {
  return new Promise((resolve) => rl.question(query, resolve));
}

async function showMenu(): Promise<string> {
  console.log("\n=== Vault User Operations Menu ===");
  console.log("1. Get vault state");
  console.log("2. Get user balance");
  console.log("3. Preview deposit");
  console.log("4. Generate deposit calldata");
  console.log("5. Generate deposit calldata with approval");
  console.log("6. Execute deposit");
  console.log("7. Preview mint");
  console.log("8. Generate mint calldata");
  console.log("9. Generate mint calldata with approval");
  console.log("10. Execute mint");
  console.log("11. Preview redeem");
  console.log("12. Generate request redeem calldata");
  console.log("13. Execute request redeem");
  console.log("14. Generate claim redeem calldata");
  console.log("15. Execute claim redeem");
  console.log("16. Check due assets for NFT");
  console.log("17. Test conversion utilities");
  console.log("0. Exit");
  console.log("=====================================");

  const choice = await question("Enter your choice (0-17): ");
  return choice.trim();
}

async function handleGetVaultState(userSDK: VaultUserSDK): Promise<void> {
  try {
    console.log("\n--- Getting vault state ---");
    const vaultState = await userSDK.getVaultState();
    console.log(`Current epoch: ${vaultState.epoch}`);
    console.log(`Total supply: ${vaultState.totalSupply}`);
    console.log(`Total assets: ${vaultState.totalAssets}`);
    console.log(`Buffer: ${vaultState.buffer}`);
    console.log(`AUM: ${vaultState.aum}`);
  } catch (error) {
    console.error("Error getting vault state:", error);
  }
}

async function handleGetUserBalance(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    console.log("\n--- Getting user balance ---");
    const userBalance = await userSDK.getUserShareBalance(account.address);
    console.log(`User share balance: ${userBalance}`);
  } catch (error) {
    console.error("Error getting user balance:", error);
  }
}

async function handlePreviewDeposit(userSDK: VaultUserSDK): Promise<void> {
  try {
    const assetsInput = await question(
      "Enter assets to deposit (e.g., 1000000 for 1 USDC): "
    );
    const assetsToDeposit = assetsInput.trim();

    console.log("\n--- Previewing deposit ---");
    console.log(`Assets to deposit: ${assetsToDeposit}`);
    const expectedShares = await userSDK.previewDeposit(assetsToDeposit);
    console.log(`Expected shares: ${expectedShares}`);
  } catch (error) {
    console.error("Error previewing deposit:", error);
  }
}

async function handleGenerateDepositCalldata(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const assetsInput = await question("Enter assets to deposit: ");
    const assetsToDeposit = assetsInput.trim();

    console.log("\n--- Generating deposit calldata ---");
    const depositCalldata = userSDK.buildDepositCalldata({
      assets: assetsToDeposit,
      receiver: account.address,
      includeApprove: true,
    });
    console.log(`Deposit calldata: ${depositCalldata}`);
  } catch (error) {
    console.error("Error generating deposit calldata:", error);
  }
}

async function handleGenerateDepositCalldataWithApproval(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const assetsInput = await question("Enter assets to deposit: ");
    const assetsToDeposit = assetsInput.trim();

    console.log("\n--- Generating deposit calldata with approval ---");
    const depositWithApprovalCalldata =
      await userSDK.buildDepositCalldataWithApproval({
        assets: assetsToDeposit,
        receiver: account.address,
        includeApprove: true,
      });
    console.log(
      `Number of transactions: ${depositWithApprovalCalldata.transactions.length}`
    );
    console.log(
      `Transaction 1 (Approve): ${depositWithApprovalCalldata.transactions[0].entrypoint}`
    );
    console.log(
      `Transaction 2 (Deposit): ${depositWithApprovalCalldata.transactions[1].entrypoint}`
    );
  } catch (error) {
    console.error("Error generating deposit calldata with approval:", error);
  }
}

async function handleExecuteDeposit(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const assetsInput = await question("Enter assets to deposit: ");
    const assetsToDeposit = assetsInput.trim();

    console.log("\n--- Executing deposit ---");
    console.log(`Assets to deposit: ${assetsToDeposit}`);

    const depositWithApprovalCalldata =
      await userSDK.buildDepositCalldataWithApproval({
        assets: assetsToDeposit,
        receiver: account.address,
        includeApprove: true,
      });

    console.log("Executing transaction...");
    const result = await account.execute(
      depositWithApprovalCalldata.transactions
    );
    console.log(`Transaction hash: ${result.transaction_hash}`);
    console.log("Deposit executed successfully!");
  } catch (error) {
    console.error("Error executing deposit:", error);
  }
}

async function handlePreviewMint(userSDK: VaultUserSDK): Promise<void> {
  try {
    const sharesInput = await question("Enter shares to mint: ");
    const sharesToMint = sharesInput.trim();

    console.log("\n--- Previewing mint ---");
    console.log(`Shares to mint: ${sharesToMint}`);
    const expectedAssets = await userSDK.previewMint(sharesToMint);
    console.log(`Expected assets required: ${expectedAssets}`);
  } catch (error) {
    console.error("Error previewing mint:", error);
  }
}

async function handleGenerateMintCalldata(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const sharesInput = await question("Enter shares to mint: ");
    const sharesToMint = sharesInput.trim();

    console.log("\n--- Generating mint calldata ---");
    const mintCalldata = userSDK.buildMintCalldata({
      shares: sharesToMint,
      receiver: account.address,
    });
    console.log(`Mint calldata: ${mintCalldata}`);
  } catch (error) {
    console.error("Error generating mint calldata:", error);
  }
}

async function handleGenerateMintCalldataWithApproval(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const sharesInput = await question("Enter shares to mint: ");
    const sharesToMint = sharesInput.trim();

    console.log("\n--- Generating mint calldata with approval ---");
    const mintWithApprovalCalldata =
      await userSDK.buildMintCalldataWithApproval({
        shares: sharesToMint,
        receiver: account.address,
        includeApprove: true,
      });
    console.log(
      `Number of transactions: ${mintWithApprovalCalldata.transactions.length}`
    );
    console.log(
      `Transaction 1 (Approve): ${mintWithApprovalCalldata.transactions[0].entrypoint}`
    );
    console.log(
      `Transaction 2 (Mint): ${mintWithApprovalCalldata.transactions[1].entrypoint}`
    );
  } catch (error) {
    console.error("Error generating mint calldata with approval:", error);
  }
}

async function handleExecuteMint(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const sharesInput = await question("Enter shares to mint: ");
    const sharesToMint = sharesInput.trim();

    console.log("\n--- Executing mint ---");
    console.log(`Shares to mint: ${sharesToMint}`);

    const mintWithApprovalCalldata =
      await userSDK.buildMintCalldataWithApproval({
        shares: sharesToMint,
        receiver: account.address,
        includeApprove: true,
      });

    console.log("Executing transaction...");
    const result = await account.execute(mintWithApprovalCalldata.transactions);
    console.log(`Transaction hash: ${result.transaction_hash}`);
    console.log("Mint executed successfully!");
  } catch (error) {
    console.error("Error executing mint:", error);
  }
}

async function handlePreviewRedeem(userSDK: VaultUserSDK): Promise<void> {
  try {
    const sharesInput = await question("Enter shares to redeem: ");
    const sharesToRedeem = sharesInput.trim();

    console.log("\n--- Previewing redeem ---");
    console.log(`Shares to redeem: ${sharesToRedeem}`);
    const expectedAssets = await userSDK.previewRedeem(sharesToRedeem);
    console.log(`Expected assets: ${expectedAssets}`);
  } catch (error) {
    console.error("Error previewing redeem:", error);
  }
}

async function handleGenerateRequestRedeemCalldata(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const sharesInput = await question("Enter shares to redeem: ");
    const sharesToRedeem = sharesInput.trim();

    console.log("\n--- Generating request redeem calldata ---");
    const redeemCalldata = userSDK.buildRequestRedeemCalldata({
      shares: sharesToRedeem,
      receiver: account.address,
      owner: account.address,
    });
    console.log(`Request redeem calldata: ${redeemCalldata}`);
  } catch (error) {
    console.error("Error generating request redeem calldata:", error);
  }
}

async function handleExecuteRequestRedeem(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const sharesInput = await question("Enter shares to redeem: ");
    const sharesToRedeem = sharesInput.trim();

    console.log("\n--- Executing request redeem ---");
    console.log(`Shares to redeem: ${sharesToRedeem}`);

    const redeemCalldata = userSDK.buildRequestRedeemCalldata({
      shares: sharesToRedeem,
      receiver: account.address,
      owner: account.address,
    });

    console.log("Executing transaction...");
    const result = await account.execute(redeemCalldata);
    console.log(`Transaction hash: ${result.transaction_hash}`);
    console.log("Request redeem executed successfully!");
  } catch (error) {
    console.error("Error executing request redeem:", error);
  }
}

async function handleGenerateClaimRedeemCalldata(
  userSDK: VaultUserSDK
): Promise<void> {
  try {
    const nftIdInput = await question("Enter NFT ID to claim: ");
    const nftId = nftIdInput.trim();

    console.log("\n--- Generating claim redeem calldata ---");
    const claimCalldata = userSDK.buildClaimRedeemCalldata({
      id: nftId,
    });
    console.log(`NFT ID: ${nftId}`);
    console.log(`Claim redeem calldata: ${claimCalldata}`);
  } catch (error) {
    console.error("Error generating claim redeem calldata:", error);
  }
}

async function handleExecuteClaimRedeem(
  userSDK: VaultUserSDK,
  account: Account
): Promise<void> {
  try {
    const nftIdInput = await question("Enter NFT ID to claim: ");
    const nftId = nftIdInput.trim();

    console.log("\n--- Executing claim redeem ---");
    console.log(`NFT ID to claim: ${nftId}`);

    const claimCalldata = userSDK.buildClaimRedeemCalldata({
      id: nftId,
    });

    console.log("Executing transaction...");
    const result = await account.execute(claimCalldata);
    console.log(`Transaction hash: ${result.transaction_hash}`);
    console.log("Claim redeem executed successfully!");
  } catch (error) {
    console.error("Error executing claim redeem:", error);
  }
}

async function handleCheckDueAssets(userSDK: VaultUserSDK): Promise<void> {
  try {
    const nftIdInput = await question("Enter NFT ID to check: ");
    const nftId = nftIdInput.trim();

    console.log("\n--- Checking due assets for NFT ---");
    const dueAssets = await userSDK.getDueAssetsFromId(nftId);
    console.log(`Due assets for NFT ${nftId}: ${dueAssets}`);
  } catch (error) {
    console.error(`Error checking due assets: ${error}`);
  }
}

async function handleConversionUtilities(userSDK: VaultUserSDK): Promise<void> {
  try {
    const assetsInput = await question("Enter assets amount to convert: ");
    const testAssets = assetsInput.trim();

    console.log("\n--- Testing conversion utilities ---");
    const convertedShares = await userSDK.convertToShares(testAssets);
    const convertedBackToAssets = await userSDK.convertToAssets(
      convertedShares
    );
    console.log(`${testAssets} assets = ${convertedShares} shares`);
    console.log(`${convertedShares} shares = ${convertedBackToAssets} assets`);
  } catch (error) {
    console.error("Error with conversion utilities:", error);
  }
}

async function userExample() {
  const provider = new RpcProvider({
    nodeUrl: "https://rpc.starknet.lava.build:443",
  });

  // Check for required environment variables
  const accountAddress = process.env.ACCOUNT_ADDRESS;
  const accountPK = process.env.ACCOUNT_PK;

  if (!accountAddress || !accountPK) {
    console.error("Missing required environment variables:");
    if (!accountAddress) console.error("- ACCOUNT_ADDRESS");
    if (!accountPK) console.error("- ACCOUNT_PK");
    console.error("Please set these environment variables and try again.");
    return;
  }

  const account = new Account(
    provider,
    accountAddress,
    accountPK,
    undefined,
    "0x3"
  );

  const userSDK = new VaultUserSDK(vaultConfig, provider);

  console.log("=== Vault User Operations Interactive Example ===");
  console.log(`Connected to vault: ${vaultConfig.vaultAddress}`);
  console.log(`Using account: ${account.address}`);

  try {
    let choice = "";
    while (choice !== "0") {
      choice = await showMenu();

      switch (choice) {
        case "1":
          await handleGetVaultState(userSDK);
          break;
        case "2":
          await handleGetUserBalance(userSDK, account);
          break;
        case "3":
          await handlePreviewDeposit(userSDK);
          break;
        case "4":
          await handleGenerateDepositCalldata(userSDK, account);
          break;
        case "5":
          await handleGenerateDepositCalldataWithApproval(userSDK, account);
          break;
        case "6":
          await handleExecuteDeposit(userSDK, account);
          break;
        case "7":
          await handlePreviewMint(userSDK);
          break;
        case "8":
          await handleGenerateMintCalldata(userSDK, account);
          break;
        case "9":
          await handleGenerateMintCalldataWithApproval(userSDK, account);
          break;
        case "10":
          await handleExecuteMint(userSDK, account);
          break;
        case "11":
          await handlePreviewRedeem(userSDK);
          break;
        case "12":
          await handleGenerateRequestRedeemCalldata(userSDK, account);
          break;
        case "13":
          await handleExecuteRequestRedeem(userSDK, account);
          break;
        case "14":
          await handleGenerateClaimRedeemCalldata(userSDK);
          break;
        case "15":
          await handleExecuteClaimRedeem(userSDK, account);
          break;
        case "16":
          await handleCheckDueAssets(userSDK);
          break;
        case "17":
          await handleConversionUtilities(userSDK);
          break;
        case "0":
          console.log("Goodbye!");
          break;
        default:
          console.log("Invalid choice. Please enter a number between 0-17.");
          break;
      }

      if (choice !== "0") {
        await question("\nPress Enter to continue...");
      }
    }
  } catch (error) {
    console.error("Error in user example:", error);
  } finally {
    rl.close();
  }
}

userExample();

export { userExample };
