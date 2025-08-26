import hre from "hardhat";
import AiPredictionV1Module from "../ignition/modules/AiPredictionV1.js"
import { SecretsManager } from "@chainlink/functions-toolkit";
import { ethers as ethers5 } from "ethers-v5";

async function main() {

    const connection = await hre.network.connect();

    const { aiPredictionV1 } = await connection.ignition.deploy(AiPredictionV1Module, {
        deploymentId: hre.globalOptions.network,
        displayUi: true
    });

    const address = await aiPredictionV1.getAddress();
    console.log(`✅ Contract deployed to: ${address}`);


    console.log(`🚀 Uploading secrets to DON...`);
    const _oracleRouter = process.env.ORACLE_FUNCTIONS_ROUTER;
    const _oracleFunDonID = process.env.ORACLE_FUN_DON_ID;
    const _openAiApiKey = process.env.OPEN_AI_API_KEY;

    if (!_oracleRouter || !_oracleFunDonID || !_openAiApiKey) {
        throw new Error("Missing environment variables for AiPredictionV1Module");
    }

    const ethersV5Provider = new ethers5.providers.JsonRpcProvider(process.env.CHAIN_RPC_URL!, {
        chainId: +process.env.CHAIN_ID!,
        name: connection.networkName
    });

    const v5Signer = new ethers5.Wallet(process.env.ACCOUNT_PRIVATE_KEY!, ethersV5Provider);

    const secretsManager = new SecretsManager({
        signer: v5Signer,
        functionsRouterAddress: process.env.ORACLE_FUNCTIONS_ROUTER!,
        donId: process.env.ORACLE_FUN_DON_ID!
    });

    await secretsManager.initialize();

    const encryptedSecretsObj = await secretsManager.encryptSecrets({
        openaiKey: process.env.OPEN_AI_API_KEY!
    });

    const {
        version, // Secrets version number (corresponds to timestamp when encrypted secrets were uploaded to DON)
        success, // Boolean value indicating if encrypted secrets were successfully uploaded to all nodes connected to the gateway
    } = await secretsManager.uploadEncryptedSecretsToDON({
        encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
        gatewayUrls: (process.env.ORACLE_ENCRYPTED_SECRETS_UPLOAD_ENDPOINTS!).split(','),
        slotId: 0,
        minutesUntilExpiration: 10,
    })

    if (!success) {
        throw Error("Mission failed")
    }

    if (success) {
        console.log(`✅ Secrets version:${version} are uploaded`);
    }

}

main().catch(console.error);
