# StarkNet Vault Kit Backend - OSS Version

**This is a reference backend (read-only) for the StarkNet Vault Kit.**

It provides minimal functionality to index vault events and expose basic API endpoints. This OSS version does not include premium features like pricing, automated redeems, SLA monitoring, or advanced analytics.

**For production deployments with full features, see our premium services.**

## What's Included

### Applications

- **`api`** - HTTP API with vault data endpoints
- **`indexer`** - Event indexer for vault reports and redeems
- **`relayerAutomaticRedeem`** - ⚠️ **INCOMPLETE** - Automatic redeem processing service
- **`relayerOnChainAum`** - ⚠️ **INCOMPLETE** - On-chain AUM management service

### Libraries

- **`@forge/config`** - Configuration management
- **`@forge/db`** - Prisma database client with Prisma schema
- **`@forge/logger`** - Structured logging with Winston
- **`@forge/starknet`** - StarkNet interaction service

## API Endpoints (6 total)

1. `GET /health` - Health check and API info
2. `GET /pending-redeems/:address` - Pending redeems for an address (with limit/offset)
3. `GET /reports/last` - Latest report from database
4. `GET /redeems/:id` - Redeem details by ID
5. `GET /strategy-analytics` - Strategy analytics with APY calculations (with limit/offset)
6. `GET /redeem-required-assets` - Required assets for pending redeems by epoch

## Events Indexed (3 total)

The indexer only tracks these events:

1. **Report** - Vault reports with epoch, supply, and assets
2. **RedeemRequested** - User redeem requests
3. **RedeemClaimed** - Completed redeem claims

## Database Schema (3 models + status)

- `Report`
- `RedeemRequested`
- `RedeemClaimed`
- `IndexerStatus`

## Quick Start with Docker (Development)

1. **Clone and setup:**

```bash
cp .env.example .env
# Edit .env with your configuration
```

2. **Run with Docker Compose (Development Mode):**

```bash
docker-compose -f docker-compose.dev.yml up -d
```

This starts:

- PostgreSQL database
- API service on port 3000 (with hot reload)
- Indexer service (with hot reload)
- ⚠️ **Note**: Relayer services have Dockerfiles but are not yet functional

3. **Available Services:**
   - API: http://localhost:3000
   - Database: localhost:5432

4. **Check health:**

```bash
curl http://localhost:3000/health
```

## Manual Setup

### Prerequisites

- Node.js 18+
- pnpm
- PostgreSQL
- Apibara token (for indexing)

### Installation

```bash
# Install dependencies
pnpm install

# Setup database
pnpm prisma:generate
pnpm prisma:migrate:deploy

# Build
pnpm build
```

### Run Services

```bash
# Start API
pnpm start:api

# Start Indexer (separate terminal)
pnpm start:indexer
```

## Configuration

Copy `.env.example` to `.env` and configure:

```bash
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/starknet_vault_kit"
RPC_URL="https://starknet-mainnet.public.blastapi.io"
VAULT_ADDRESS="0x..." # Your vault contract address
START_BLOCK=12993
APIBARA_TOKEN="your_token_here"
```

## License

This project is licensed for reference use only. For production deployments with full features and support, please contact us.

---

_Built for the StarkNet ecosystem 🚀_
