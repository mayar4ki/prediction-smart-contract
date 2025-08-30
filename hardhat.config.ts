import type { HardhatUserConfig } from "hardhat/config";
import HardhatIgnitionEthersPlugin from '@nomicfoundation/hardhat-ignition-ethers'
import { NetworkUserConfig } from "hardhat/types/config";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import { configVariable } from "hardhat/config";

// const avalancheMainnet: NetworkUserConfig = {
//   type: "http",
//   url: "https://api.avax.network/ext/bc/C/rpc",
//   chainId: 43114,
//   accounts: [configVariable("ACCOUNT_PRIVATE_KEY")],
// };

// const avalancheFujiTestnet: NetworkUserConfig = {
//   type: "http",
//   url: "https://api.avax-test.network/ext/bc/C/rpc",
//   chainId: 43113,
//   accounts: [configVariable("ACCOUNT_PRIVATE_KEY")]
// };

const sepolia: NetworkUserConfig = {
  type: "http",
  url: process.env.CHAIN_RPC_URL!,
  chainId: +process.env.CHAIN_ID!,
  accounts: [process.env.ACCOUNT_PRIVATE_KEY!]
};


const config: HardhatUserConfig = {
  plugins: [HardhatIgnitionEthersPlugin, hardhatVerify],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }
        },
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          }
        },
      },
    },
  },
  networks: {
    // sepolia,
    // avalancheMainnet,
    // avalancheFujiTestnet
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  verify: {
    etherscan: {
      apiKey: configVariable("ETHERSCAN_API_KEY")
    },
    blockscout: {
      enabled: false,
    }
  }
};
export default config;
