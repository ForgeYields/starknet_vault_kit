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

The `VaultCuratorSDK` enables curators to execute DeFi operations through the vault allocator using Merkle-verified calldata. It supports multiple protocol integrations.

#### Initialization

```typescript
import { VaultCuratorSDK } from '@starknet-vault-kit/sdk';

// Load from a vault config JSON file
const sdk = VaultCuratorSDK.fromFile('./vault-config.json');

// Or initialize with config object
const sdk = new VaultCuratorSDK(vaultConfig);
```

#### Core Methods

- `buildCall(operations)` - Build a multicall from multiple `MerkleOperation` objects
- `bringLiquidity(params)` - Move liquidity from buffer to allocator
- `approve(params)` - Approve tokens for a spender

#### Integrations

##### ERC4626 (Nested Vault Operations)

Interact with other ERC-4626 vaults:

- `deposit(params)` - Deposit assets into a vault
- `mint(params)` - Mint shares from a vault
- `withdraw(params)` - Withdraw assets from a vault
- `redeem(params)` - Redeem shares for assets
- `requestRedeem(params)` - Request async redemption (epoched vaults)
- `claimRedeem(params)` - Claim completed async redemption

##### AVNU (DEX Aggregator)

Execute token swaps via AVNU:

- `multiRouteSwap(params)` - Execute multi-hop token swaps with optimal routing

##### Vesu V2 (Lending Protocol)

Manage lending positions on Vesu V2:

- `modifyPositionV2(params)` - Supply collateral, borrow, repay, or withdraw

##### Ekubo (DEX Liquidity)

Provide liquidity on Ekubo DEX:

- `ekuboDepositLiquidity(params)` - Deposit liquidity to a pool
- `ekuboWithdrawLiquidity(params)` - Withdraw liquidity from a pool
- `ekuboCollectFees(params)` - Collect accumulated trading fees
- `ekuboHarvest(params)` - Harvest farming rewards

##### Starkgate (L1 Bridge)

Bridge tokens between Starknet and Ethereum:

- `bridgeTokenStarkgate(params)` - Initiate token withdrawal to L1
- `claimTokenStarkgate(params)` - Claim tokens bridged back from L1

##### Hyperlane (Cross-Chain Bridge)

Bridge tokens across chains via Hyperlane:

- `bridgeTokenHyperlane(params)` - Bridge tokens to another chain
- `claimTokenHyperlane(params)` - Claim bridged tokens

##### CCTP (Circle Cross-Chain Transfer)

Bridge USDC via Circle's CCTP:

- `bridgeTokenCctp(params)` - Bridge USDC to another chain
- `claimTokenCctp(params)` - Claim bridged USDC

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

### Curator Operations (Allocator SDK)

```typescript
import { VaultCuratorSDK } from '@starknet-vault-kit/sdk';
import { Account, RpcProvider } from 'starknet';

// Load SDK from vault config file
const sdk = VaultCuratorSDK.fromFile('./vault-config.json');

const provider = new RpcProvider({ nodeUrl: "your-node-url" });
const curatorAccount = new Account(provider, "0x...", "your-private-key");

// Example 1: Swap tokens via AVNU
const swapOp = sdk.multiRouteSwap({
  target: "0x...", // AVNU middleware address
  sell_token_address: "0x...", // STRK
  sell_token_amount: "1000000000000000000", // 1 STRK
  buy_token_address: "0x...", // USDC
  buy_token_amount: "500000", // Expected USDC
  buy_token_min_amount: "490000", // Min USDC (slippage)
  beneficiary: "0x...", // Vault allocator
  integrator_fee_amount_bps: 0,
  integrator_fee_recipient: "0x0",
  routes: [/* route data from AVNU API */]
});

// Example 2: Supply collateral to Vesu V2
const vesuOp = sdk.modifyPositionV2({
  target: "0x...", // Vesu pool
  collateral_asset: "0x...", // USDC
  debt_asset: "0x...", // ETH
  user: "0x...", // Vault allocator
  collateral: { denomination: "Native", value: { abs: "1000000", is_negative: false } },
  debt: { denomination: "Native", value: { abs: "0", is_negative: false } }
});

// Example 3: Provide liquidity on Ekubo
const ekuboOp = sdk.ekuboDepositLiquidity({
  target: "0x...", // Ekubo adapter
  amount0: "1000000",
  amount1: "1000000"
});

// Build and execute a multicall with multiple operations
const approveOp = sdk.approve({
  target: "0x...", // Token to approve
  spender: "0x...", // Protocol contract
  amount: "1000000000"
});

const call = sdk.buildCall([approveOp, swapOp]);

const tx = await curatorAccount.execute(call);
console.log("Transaction hash:", tx.transaction_hash);
```

## License

MIT