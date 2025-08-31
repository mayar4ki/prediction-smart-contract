import hre from "hardhat";
import { ethers as ethers5 } from "ethers-v5";
import { envValidationSchema } from "../utils/envValidationSchema.js";



export const initializeConnections = async () => {
    console.log(`Initializing Connections... \n`);
    const env = envValidationSchema.parse(process.env);
    const connection = await hre.network.connect();
    const ethersV5Provider = new ethers5.providers.JsonRpcProvider(env.CHAIN_RPC_URL, {
        chainId: env.CHAIN_ID,
        name: connection.networkName
    });
    const v5Signer = new ethers5.Wallet(env.ACCOUNT_PRIVATE_KEY, ethersV5Provider);
    console.log(`🚀 Deploying... \n`);

    return {
        env,
        connection,
        ethersV5Provider,
        v5Signer
    }
}

export type Connections = Awaited<ReturnType<typeof initializeConnections>>