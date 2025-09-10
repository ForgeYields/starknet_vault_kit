import fs from "fs";
import path from "path";

const CONFIG_FILE = path.join(__dirname, "config.json");

export interface NetworkConfig {
  [key: string]: any;
}

export interface Config {
  [networkName: string]: NetworkConfig;
}

export function readConfigs(): Config {
  try {
    if (!fs.existsSync(CONFIG_FILE)) {
      const defaultConfig: Config = {
        sepolia: {
          hash: {},
          periphery: {}
        },
        mainnet: {
          hash: {},
          periphery: {}
        }
      };
      writeConfigs(defaultConfig);
      return defaultConfig;
    }
    
    const configData = fs.readFileSync(CONFIG_FILE, "utf8");
    return JSON.parse(configData) as Config;
  } catch (error) {
    console.error("Error reading config file:", error);
    throw new Error("Failed to read configuration");
  }
}

export function writeConfigs(config: Config): void {
  try {
    const configData = JSON.stringify(config, null, 2);
    fs.writeFileSync(CONFIG_FILE, configData, "utf8");
    console.log("Configuration saved successfully");
  } catch (error) {
    console.error("Error writing config file:", error);
    throw new Error("Failed to write configuration");
  }
}