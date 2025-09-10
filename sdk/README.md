# Starknet Vault Kit SDK

TypeScript SDK for interacting with Starknet Vault Kit contracts. Provides easy-to-use interfaces for both vault users and curators to interact with ERC-4626 compatible vaults with epoched redemption systems.

## Features

- **User Operations**: Deposit, mint, request redemptions, and claim redemptions
- **Curator Operations**: Report AUM, manage liquidity, configure fees, and pause/unpause
- **Calldata Generation**: Generate transaction calldata for all operations
- **State Queries**: Read vault state, balances, fees, and redemption information
- **Type Safety**: Full TypeScript support with proper types

## Installation

```bash
npm install @starknet-vault-kit/sdk
# or
yarn add @starknet-vault-kit/sdk
```

## Quick Start

### User Operations

```typescript
import { VaultUserSDK, VaultConfig } from '@starknet-vault-kit/sdk';
import { RpcProvider } from 'starknet';

// Configure vault - only vault address is required
const vaultConfig: VaultConfig = {
  vaultAddress: "0x...",
};

// Initialize SDK with provider
const provider = new RpcProvider({ nodeUrl: "https://starknet-mainnet.public.blastapi.io" });
const userSDK = new VaultUserSDK(vaultConfig, provider);

// Generate deposit calldata
const depositCalldata = userSDK.buildDepositCalldata({
  assets: "1000000", // 1 USDC (6 decimals)
  receiver: "0x..."
});

// Generate deposit calldata WITH approval (async)
const depositWithApproval = await userSDK.buildDepositCalldataWithApproval({
  assets: "1000000",
  receiver: "0x...",
  includeApprove: true
});
// Returns { transactions: [approveCalldata, depositCalldata] }

// Get vault state
const vaultState = await userSDK.getVaultState();
console.log("Current epoch:", vaultState.epoch);

// Preview deposit
const expectedShares = await userSDK.previewDeposit("1000000");
console.log("Expected shares:", expectedShares);
```

### Curator Operations

```typescript
import { VaultCuratorSDK } from '@starknet-vault-kit/sdk';

const curatorSDK = new VaultCuratorSDK(vaultConfig, provider);

// Generate report calldata
const reportCalldata = curatorSDK.buildReportCalldata({
  newAum: "5000000000" // New AUM value
});

// Check if report can be made
const canReport = await curatorSDK.canReport();
console.log("Can report:", canReport);

// Get pending redemption requirements
const pendingRedemptions = await curatorSDK.getPendingRedemptionRequirements();
console.log("Total pending assets:", pendingRedemptions.totalPendingAssets);
```

## API Reference

### VaultUserSDK

#### Calldata Generation

- `buildDepositCalldata(params)` - Generate deposit transaction calldata
- `buildDepositCalldataWithApproval(params)` - Generate deposit with approval (async)
- `buildMintCalldata(params)` - Generate mint transaction calldata  
- `buildMintCalldataWithApproval(params)` - Generate mint with approval (async)
- `buildRequestRedeemCalldata(params)` - Generate redeem request calldata
- `buildClaimRedeemCalldata(params)` - Generate claim redemption calldata

#### View Methods

- `getVaultState()` - Get current vault state (epoch, buffer, AUM, etc.)
- `getUserShareBalance(address)` - Get user's share balance
- `previewDeposit(assets)` - Preview shares received for deposit
- `previewMint(shares)` - Preview assets needed for mint
- `previewRedeem(shares)` - Preview assets received for redemption
- `getDueAssetsFromId(id)` - Get expected assets for redemption NFT
- `convertToShares(assets)` - Convert assets to shares
- `convertToAssets(shares)` - Convert shares to assets
- `getUnderlyingAssetAddress()` - Get underlying asset contract address
- `getRedeemRequestAddress()` - Get redeem request NFT contract address

### VaultCuratorSDK

#### Calldata Generation

- `buildReportCalldata(params)` - Generate AUM report calldata
- `buildBringLiquidityCalldata(params)` - Generate bring liquidity calldata
- `buildPauseCalldata()` - Generate pause calldata
- `buildUnpauseCalldata()` - Generate unpause calldata
- `buildSetFeesConfigCalldata(...)` - Generate fee configuration calldata
- `buildSetReportDelayCalldata(delay)` - Generate report delay calldata
- `buildSetMaxDeltaCalldata(delta)` - Generate max delta calldata

#### View Methods

- `getFeesConfig()` - Get current fee configuration
- `getReportDelay()` - Get minimum report delay
- `getMaxDelta()` - Get maximum AUM delta per report
- `getLastReportTimestamp()` - Get last report timestamp
- `canReport()` - Check if report can be made
- `getTimeUntilNextReport()` - Get time until next report allowed
- `getPendingRedemptionRequirements()` - Get pending redemption info
- `isPaused()` - Check if vault is paused
- `getCurrentEpoch()` - Get current epoch
- `getBuffer()` - Get current buffer amount
- `getAum()` - Get current AUM

## Types

### VaultConfig
```typescript
interface VaultConfig {
  vaultAddress: string; // Only vault address is required - other addresses are fetched automatically
}
```

### CalldataResult
```typescript
interface CalldataResult {
  contractAddress: string;
  entrypoint: string;
  calldata: string[];
}
```

### MultiCalldataResult
```typescript
interface MultiCalldataResult {
  transactions: CalldataResult[]; // Array of transactions to execute in order
}
```

### VaultState
```typescript
interface VaultState {
  epoch: bigint;
  handledEpochLen: bigint;
  buffer: bigint;
  aum: bigint;
  totalSupply: bigint;
  totalAssets: bigint;
}
```

## Examples

### Complete User Flow

```typescript
import { VaultUserSDK, VaultConfig } from '@starknet-vault-kit/sdk';
import { Account, RpcProvider } from 'starknet';

const vaultConfig: VaultConfig = {
  vaultAddress: "0x123...",
};

const provider = new RpcProvider({ nodeUrl: "your-node-url" });
const account = new Account(provider, "0x...", "your-private-key");
const userSDK = new VaultUserSDK(vaultConfig, provider);

// 1. Check current vault state
const vaultState = await userSDK.getVaultState();
console.log("Vault epoch:", vaultState.epoch);

// 2. Preview deposit
const assetsToDeposit = "1000000"; // 1 USDC
const expectedShares = await userSDK.previewDeposit(assetsToDeposit);
console.log("Expected shares:", expectedShares);

// 3. Generate and execute deposit
const depositCalldata = userSDK.buildDepositCalldata({
  assets: assetsToDeposit,
  receiver: account.address
});

const tx = await account.execute([{
  contractAddress: depositCalldata.contractAddress,
  entrypoint: depositCalldata.entrypoint,
  calldata: depositCalldata.calldata
}]);

console.log("Deposit tx:", tx.transaction_hash);

// Alternative: Deposit with approval in one transaction batch
const depositWithApprovalCalldata = await userSDK.buildDepositCalldataWithApproval({
  assets: assetsToDeposit,
  receiver: account.address,
  includeApprove: true
});

const approvalTx = await account.execute(
  depositWithApprovalCalldata.transactions.map(tx => ({
    contractAddress: tx.contractAddress,
    entrypoint: tx.entrypoint,
    calldata: tx.calldata
  }))
);

console.log("Approval + Deposit tx:", approvalTx.transaction_hash);

// 4. Later, request redemption
const userShares = await userSDK.getUserShareBalance(account.address);
const redeemCalldata = userSDK.buildRequestRedeemCalldata({
  shares: userShares / 2n, // Redeem half
  receiver: account.address,
  owner: account.address
});

const redeemTx = await account.execute([{
  contractAddress: redeemCalldata.contractAddress,
  entrypoint: redeemCalldata.entrypoint,
  calldata: redeemCalldata.calldata
}]);

console.log("Redeem request tx:", redeemTx.transaction_hash);
```

### Curator Operations

```typescript
import { VaultCuratorSDK } from '@starknet-vault-kit/sdk';

const curatorSDK = new VaultCuratorSDK(vaultConfig, provider);

// Check report status
const canReport = await curatorSDK.canReport();
if (!canReport) {
  const timeUntilReport = await curatorSDK.getTimeUntilNextReport();
  console.log(`Must wait ${timeUntilReport} seconds before next report`);
  return;
}

// Get current state for report
const [currentAum, buffer, pendingRedemptions] = await Promise.all([
  curatorSDK.getAum(),
  curatorSDK.getBuffer(),
  curatorSDK.getPendingRedemptionRequirements()
]);

console.log("Current AUM:", currentAum);
console.log("Buffer:", buffer);
console.log("Pending redemptions:", pendingRedemptions.totalPendingAssets);

// Generate report with new AUM
const newAum = "5500000000"; // Updated AUM from strategy
const reportCalldata = curatorSDK.buildReportCalldata({ newAum });

// Execute report
const reportTx = await curatorAccount.execute([{
  contractAddress: reportCalldata.contractAddress,
  entrypoint: reportCalldata.entrypoint,
  calldata: reportCalldata.calldata
}]);

console.log("Report tx:", reportTx.transaction_hash);
```

## License

MIT