import { plainToClass, Transform } from "class-transformer";
import {
  IsNumber,
  IsOptional,
  validateSync,
  IsString,
  IsBoolean,
} from "class-validator";

// Base environment variables needed by all services
export class BaseEnvironmentVariables {
  @IsString()
  DATABASE_URL: string;
}

// API-specific environment variables
export class ApiEnvironmentVariables extends BaseEnvironmentVariables {
  @IsOptional()
  @IsNumber()
  @Transform(({ value }) => Number(value))
  PORT = 3000;

  @IsString()
  RPC_URL: string;

  @IsString()
  VAULT_ADDRESS: string;
}

// Indexer-specific environment variables
export class IndexerEnvironmentVariables extends BaseEnvironmentVariables {
  @IsString()
  APIBARA_TOKEN: string;

  @IsString()
  VAULT_ADDRESS: string;

  @IsOptional()
  @IsNumber()
  @Transform(({ value }) => Number(value))
  START_BLOCK?: number;

  @IsOptional()
  @IsBoolean()
  @Transform(({ value }) => value === "true" || value === true)
  FORCE_START_BLOCK?: boolean;
}

// RelayerAutomaticRedeem-specific environment variables
export class RelayerAutomaticRedeemEnvironmentVariables extends BaseEnvironmentVariables {
  @IsString()
  RPC_URL: string;

  @IsString()
  VAULT_ADDRESS: string;

  @IsString()
  RELAYER_ADDRESS: string;

  @IsString()
  RELAYER_PRIVATE_KEY: string;

  @IsOptional()
  @IsString()
  CRON_SCHEDULE = "*/5 * * * *";
}

// RelayerOnChainAum-specific environment variables
export class RelayerOnChainAumEnvironmentVariables extends BaseEnvironmentVariables {
  @IsString()
  RPC_URL: string;

  @IsString()
  VAULT_ADDRESS: string;

  @IsString()
  RELAYER_ADDRESS: string;

  @IsString()
  RELAYER_PRIVATE_KEY: string;

  @IsString()
  ON_CHAIN_AUM_PROVIDER: string;
}

// Generic validation function
function validateConfig<T extends object>(
  EnvClass: new () => T,
  config: Record<string, unknown>
): T {
  const validatedConfig = plainToClass(EnvClass, config);

  const validatorOptions = { skipMissingProperties: false };
  const errors = validateSync(validatedConfig, validatorOptions);

  if (errors.length > 0) {
    console.error(errors.toString());
    process.exit(1);
  }

  return validatedConfig;
}

// Export specific validation functions for each service
export function validateApiConfig(config: Record<string, unknown>) {
  return validateConfig(ApiEnvironmentVariables, config);
}

export function validateIndexerConfig(config: Record<string, unknown>) {
  return validateConfig(IndexerEnvironmentVariables, config);
}

export function validateRelayerAutomaticRedeemConfig(
  config: Record<string, unknown>
) {
  return validateConfig(RelayerAutomaticRedeemEnvironmentVariables, config);
}

export function validateRelayerOnChainAumConfig(
  config: Record<string, unknown>
) {
  return validateConfig(RelayerOnChainAumEnvironmentVariables, config);
}
