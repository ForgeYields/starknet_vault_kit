# Logging Guide

## Overview

The StarkNet Vault Kit backend uses Winston for structured logging across all applications. The logging system provides clean, consistent output with support for both console and file logging.

## Configuration

Logging can be configured via environment variables:

```bash
# Log level (error, warn, info, debug)
LOG_LEVEL=info

# Enable file logging (automatically enabled in production)
ENABLE_FILE_LOGGING=false

# Directory for log files
LOG_DIR=logs

# Environment (affects log format)
NODE_ENV=development
```

## Log Levels

- **error**: Error messages and stack traces
- **warn**: Warning messages
- **info**: General information (default)
- **debug**: Detailed debugging information

## Output Format

### Development (Console)
```
10:45:23 info [API:Main] Server started on port 3000
10:45:24 debug [Indexer:Service] Processing block {
  "blockNumber": 12345,
  "timestamp": 1234567890
}
```

### Production (JSON)
```json
{
  "timestamp": "2024-01-01T10:45:23.000Z",
  "level": "info",
  "service": "starknet-vault-kit",
  "context": "API:Main",
  "message": "Server started on port 3000",
  "environment": "production"
}
```

## Usage in Code

```typescript
import { Logger } from "@forge/logger";

// Create a logger with context
const logger = Logger.create("MyService");

// Log messages
logger.info("Service started");
logger.debug("Processing data", { count: 100 });
logger.warn("High memory usage", { usage: "85%" });
logger.error("Failed to process", error);
```

## File Logging

When file logging is enabled, logs are written to:
- `logs/starknet-vault-kit-YYYY-MM-DD.log` - All logs
- `logs/starknet-vault-kit-error-YYYY-MM-DD.log` - Error logs only

Files are automatically rotated daily and kept for 14 days.

## Best Practices

1. **Use appropriate log levels**
   - `error`: For errors that need immediate attention
   - `warn`: For potential issues or degraded performance
   - `info`: For important application events
   - `debug`: For detailed debugging information

2. **Include context in log messages**
   ```typescript
   logger.info("Processing redeem", { 
     redeemId: 123, 
     user: "0x..." 
   });
   ```

3. **Avoid logging sensitive information**
   - Never log private keys, passwords, or tokens
   - Truncate addresses when appropriate

4. **Keep messages concise**
   - Use clear, descriptive messages
   - Avoid emojis and special characters
   - Put details in metadata objects

## Application Contexts

Each application uses its own context prefix:

- **API**: `API:Main`, `API:Service`, `API:Controller`
- **Indexer**: `Indexer:Main`, `Indexer:Service`
- **RelayerAutomaticRedeem**: `RelayerAutomaticRedeem:Main`, `RelayerAutomaticRedeem:Service`
- **StarkNet**: `Starknet:Service`

## Monitoring

In production, logs can be aggregated and monitored using tools like:
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Datadog
- New Relic
- CloudWatch (AWS)

The JSON format makes it easy to parse and query logs in these systems.