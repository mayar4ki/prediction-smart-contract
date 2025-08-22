import type { HardhatUserConfig } from "hardhat/config";
import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";
import { NetworkUserConfig } from "hardhat/types/config";


const avalancheMainnet: NetworkUserConfig = {
  type: "http",
  url: "https://api.avax.network/ext/bc/C/rpc",
  chainId: 43114,
  accounts: [process.env.ACCOUNT_PRIVATE_KEY!],
};

const avalancheFujiTestnet: NetworkUserConfig = {
  type: "http",
  url: "https://api.avax-test.network/ext/bc/C/rpc",
  chainId: 43113,
  accounts: [process.env.ACCOUNT_PRIVATE_KEY!]
};

const sepolia: NetworkUserConfig = {
  type: "http",
  chainType: "l1",
  url: "https://rpc.sepolia.org/",
  accounts: [process.env.ACCOUNT_PRIVATE_KEY!],
};


const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    sepolia,
    avalancheMainnet,
    avalancheFujiTestnet,
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
