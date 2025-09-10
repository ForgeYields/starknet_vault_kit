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
