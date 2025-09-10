import fs from "fs";
import path from "path";

interface DeploymentInfo {
  address: string;
  transactionHash: string;
  timestamp: number;
}

interface NetworkDeployments {
  [contractName: string]: DeploymentInfo;
  [symbol: string]: {
    vault?: DeploymentInfo;
    redeemRequest?: DeploymentInfo;
    vaultAllocator?: DeploymentInfo;
    manager?: DeploymentInfo;
  };
}

interface DeploymentsJson {
  [network: string]: NetworkDeployments;
}

const DEPLOYMENTS_FILE = path.join(__dirname, "../deployments.json");

export function readDeployments(): DeploymentsJson {
  try {
    if (!fs.existsSync(DEPLOYMENTS_FILE)) {
      return { sepolia: {}, mainnet: {} };
    }
    const data = fs.readFileSync(DEPLOYMENTS_FILE, "utf8");
    return JSON.parse(data);
  } catch (error) {
    console.warn("Warning: Could not read deployments.json, creating new one");
    return { sepolia: {}, mainnet: {} };
  }
}

export function writeDeployments(deployments: DeploymentsJson): void {
  try {
    fs.writeFileSync(DEPLOYMENTS_FILE, JSON.stringify(deployments, null, 2));
  } catch (error) {
    console.error("Error writing deployments.json:", error);
    throw error;
  }
}

export function saveContractDeployment(
  network: string,
  contractName: string,
  address: string,
  transactionHash: string
): void {
  const deployments = readDeployments();

  if (!deployments[network]) {
    deployments[network] = {};
  }

  deployments[network][contractName] = {
    address,
    transactionHash,
    timestamp: Date.now(),
  };

  writeDeployments(deployments);
}

export function saveVaultDeployment(
  network: string,
  symbol: string,
  contractType: "vault" | "redeemRequest" | "vaultAllocator" | "manager",
  address: string,
  transactionHash: string
): void {
  const deployments = readDeployments();

  if (!deployments[network]) {
    deployments[network] = {};
  }

  if (
    !deployments[network][symbol] ||
    typeof deployments[network][symbol] !== "object"
  ) {
    deployments[network][symbol] = {} as any;
  }

  (deployments[network][symbol] as any)[contractType] = {
    address,
    transactionHash,
    timestamp: Date.now(),
  };

  writeDeployments(deployments);
}
