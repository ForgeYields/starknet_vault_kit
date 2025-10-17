# StarkNet Vault Kit

A comprehensive vault infrastructure for StarkNet that provides ERC-4626 compliant vaults with advanced features including delayed redemptions, fund allocation management, and secure call execution through Merkle proof verification.

## Overview

The StarkNet Vault Kit consists of two main packages:

- **`vault`** - Core vault implementation with ERC-4626 compliance and delayed redemption system
- **`vault_allocator`** - Fund allocation management with secure call execution and Merkle proof verification

## Features

### Vault Package

- **ERC-4626 Compliance**: Standard tokenized vault interface for deposits and withdrawals
- **Delayed Redemption System**: Secure redemption requests with epoch-based processing
- **Fee Management**: Configurable management, performance, and redemption fees
- **Asset Under Management (AUM) Reporting**: Regular reporting with delta verification
- **Liquidity Management**: Buffer management for immediate withdrawals
- **Pausable Operations**: Emergency pause/unpause functionality

### Vault Allocator Package

- **Fund Allocation**: Secure allocation of vault funds to external protocols
- **Merkle Proof Verification**: Secure call execution with whitelist verification
- **Decoders & Sanitizers**: Pre-built modules for popular protocols:
  - AVNU Exchange integration
  - ERC-4626 vault operations
  - Vesu protocol integration
  - Simple operations (approvals, transfers)
- **Manager System**: Role-based access control for fund management
- **Multi-call Support**: Batch execution of verified calls

## Package Details

### Vault (`packages/vault`)

The vault package provides:

- **Vault Contract** (`vault/vault.cairo`): Main ERC-4626 compliant vault with delayed redemptions
- **Redeem Request System** (`redeem_request/`): NFT-based redemption request tracking
- **Fee System**: Management, performance, and redemption fee handling
- **Reporting**: AUM reporting with configurable delays and delta verification

Key interfaces:

- Deposit/withdrawal operations (ERC-4626)
- Request redemption for delayed withdrawals
- Claim redemption after epoch processing
- Fee configuration and collection
- AUM reporting and liquidity management

### Vault Allocator (`packages/vault_allocator`)

The vault allocator package provides:

- **Vault Allocator Contract** (`vault_allocator/vault_allocator.cairo`): Fund allocation with call execution
- **Manager System** (`manager/`): Merkle proof-based call verification
- **Decoders & Sanitizers** (`decoders_and_sanitizers/`): Protocol-specific call handlers

Key features:

- Secure fund allocation through Merkle proofs
- Protocol integrations (AVNU, Vesu, ERC-4626)
- Batch call execution
- Role-based access control

## Getting Started

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/) (2.12.0+)
- [Starknet Foundry](https://github.com/foundry-rs/starknet-foundry) (0.48.0)

### Installation

```bash
# Clone the repository
git clone https://github.com/ForgeYields/starknet_vault_kit.git
cd starknet_vault_kit

# Build the project
scarb build

# Run tests
snforge test
```

## Get Started as a Vault Builder

This guide walks you through deploying and configuring vaults as a builder, covering both custodial and non-custodial approaches.

### Step 1: Deploy Your Vault

Use the deployment script to create your vault with the desired configuration:

```bash
cd scripts
npm run deploy:vault
```

The script (`scripts/deployVault.ts`) will prompt you for:
- **Vault Details**: Name, symbol, underlying asset address
- **Fee Configuration**: Management, performance, and redemption fees
- **Operational Parameters**: Report delay, max delta percentage, fees recipient
- **Vault Type**: Choose between custodial or non-custodial

#### Custodial vs Non-Custodial Vaults

**Custodial Vaults:**
- Use an existing, pre-deployed VaultAllocator
- Suitable when you trust a third-party allocator
- Faster deployment (vault + redeem request only)
- Limited control over fund allocation strategies

**Non-Custodial Vaults:**
- Deploy a new VaultAllocator and Manager specific to your vault
- Full control over fund allocation and strategy management
- Requires additional setup for Merkle tree verification system
- Higher security and customization capabilities

### Step 2: Non-Custodial Setup (Advanced Fund Management)

For non-custodial vaults, you need to set up the Merkle tree verification system for secure fund allocation:

#### 2.1 Configure Allocation Strategies

The VaultAllocator (`packages/vault_allocator`) provides secure fund allocation through:
- **Manager Contract**: Merkle proof-based call verification
- **Decoders & Sanitizers**: Pre-built integrations for protocols (AVNU, Vesu, ERC-4626)
- **Merkle Tree Verification**: Whitelist system for allowed operations

#### 2.2 Generate Merkle Tree Configuration

Run the merkle tree generation script to create your allocation whitelist:

```bash
./export_merkle.sh [config_name]
```

This script:
1. Executes test scenarios to generate valid operation leafs
2. Creates a Merkle tree with allowed operations
3. Outputs a JSON configuration file in `leafs/[config_name].json`

The generated file contains:
- **Metadata**: Vault, allocator, and manager addresses
- **Leafs**: Whitelisted operations with their proofs
- **Tree**: Complete Merkle tree structure

#### 2.3 Set Management Root

Configure the Manager contract with your Merkle root:

```typescript
// Using the deployed manager address from step 1
const manager = new Contract(managerAbi, managerAddress, account);
await manager.set_manage_root(vaultAddress, merkleRoot);
```

### Step 3: Off-Chain Integration with Curator SDK

Use the Curator SDK (`sdk/src/curator/index.ts`) to generate secure calldata for vault operations:

#### 3.1 Initialize the SDK

```typescript
import { VaultCuratorSDK } from './sdk/src/curator';

// Load configuration from generated merkle file
const curator = VaultCuratorSDK.fromFile('./leafs/your_config.json');
```

#### 3.2 Generate Operation Calldata

The SDK provides helper methods for common operations:

```typescript
// Bring liquidity to vault
const calls = curator.bringLiquidityHelper(true, amount); // true = with approval

// Multi-step operations (approve + deposit)
const calls = curator.depositHelper({
  target: vaultAddress,
  assets: depositAmount,
  receiver: userAddress,
  withApproval: true
});

// Advanced DeFi operations
const calls = curator.multiRouteSwapHelper(swapParams, { withApproval: true });
const calls = curator.ModifyPositionV1Helper(vesuParams, approvalParams);
```

#### 3.3 Execute Operations

```typescript
// Execute the generated calls
const response = await account.execute(calls);
```

### Key Benefits

- **Security**: Merkle proof verification ensures only whitelisted operations
- **Flexibility**: Support for multiple DeFi protocols (AVNU, Vesu, ERC-4626)
- **Efficiency**: Batch operations with automatic approval handling
- **Auditability**: All operations are pre-defined and verifiable

### Next Steps

1. **Monitor**: Use the backend services for vault monitoring and analytics
2. **Optimize**: Adjust strategies based on performance metrics
3. **Scale**: Deploy multiple vaults with different strategies
4. **Integrate**: Use the SDK in your applications for seamless vault management

### Scripts & Backend

For deployment scripts and configuration utilities, see [scripts/README.md](scripts/README.md).

For backend services (API and indexer), see [backend/README.md](backend/README.md).

## Testing

The project includes comprehensive test suites:

- **Unit Tests**: Core functionality testing for both packages
- **Integration Tests**: fork mainnet vault allocator integration of other DeFi protocols testing
- **Mock Contracts**: Test utilities and protocol mocks

Run tests with:

```bash
# Run all tests
snforge test

# Run specific package tests
snforge test -p vault
snforge test -p vault_allocator

# Run with coverage
snforge test --coverage
```

## Security

- All call executions are verified through Merkle proofs
- Role-based access control for fund management
- Pausable operations for emergency stops
- Comprehensive input validation and sanitization

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Contact

ForgeYields - forge.fi.contact@gmail.com

Project Link: [https://github.com/ForgeYields/starknet_vault_kit](https://github.com/ForgeYields/starknet_vault_kit)
