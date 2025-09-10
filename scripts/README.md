# StarkNet Vault Kit Scripts

Collection of deployment and management scripts for the StarkNet Vault Kit.

## Prerequisites

- Node.js and pnpm installed
- StarkNet account with sufficient balance
- Environment variables configured in `.env`

## Environment Setup

Create a `.env` file in the project root with:

```env
RPC=<your_starknet_rpc_url>
ACCOUNT_ADDRESS=<your_account_address>
ACCOUNT_PK=<your_private_key>
```

## Available Scripts

### Contract Declaration

```bash
# Declare any contract
pnpm declare --contract <ContractName>

# Declare specific contracts
pnpm declare:vault
pnpm declare:vault-allocator
pnpm declare:redeem-request
pnpm declare:avnu-middleware
pnpm declare:manager
pnpm declare:price-router
pnpm declare:decoder-sanitizer
```

### Contract Deployment

```bash
# Deploy any contract
pnpm deploy --contract <ContractName>

# Deploy vault with interactive setup
pnpm deploy:vault
```

### Configuration Management

```bash
# Configure vault settings
pnpm vault:config

# Configure manager settings
pnpm manager:config
```

## Script Details

### `declareContract.ts`

Declares Cairo contracts on StarkNet. Supports all vault ecosystem contracts.

### `deployContract.ts`

Deploys declared contracts with constructor parameters.

### `deployVault.ts`

Interactive vault deployment with automatic dependency setup.

### `vaultConfig.ts`

Interactive vault configuration management:

- Set fees configuration (redeem, management, performance)
- Configure report delays
- Set max delta parameters

### `managerConfig.ts`

Interactive manager configuration:

- Set manage root (merkle tree root for strategist targets)

## Usage Examples

```bash
# Full deployment workflow
pnpm declare:vault
pnpm declare:vault-allocator
pnpm deploy:vault

# Configure deployed vault
pnpm vault:config

# Set up manager permissions
pnpm manager:config
```

## Notes

- All scripts use interactive prompts for safe parameter input
- Transaction hashes are displayed for verification
- Deployment addresses are saved to `deployments.json`
- Scripts validate inputs before execution
- Network detection is automatic based on RPC endpoint
