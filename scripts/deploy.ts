import hre from "hardhat";
import { SecretsManager, SubscriptionManager } from "@chainlink/functions-toolkit";
import { ethers as ethers5 } from "ethers-v5";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "ethers";
import { envValidationSchema } from "./envValidationSchema.js";


async function main() {

    const env = envValidationSchema.parse(process.env);
    const connection = await hre.network.connect();

    console.log(`🚀 Deploying... \n`);

    const ethersV5Provider = new ethers5.providers.JsonRpcProvider(env.CHAIN_RPC_URL, {
        chainId: env.CHAIN_ID,
        name: connection.networkName
    });

    const v5Signer = new ethers5.Wallet(env.ACCOUNT_PRIVATE_KEY, ethersV5Provider);

    const subscriptionManager = new SubscriptionManager({
        signer: v5Signer,
        linkTokenAddress: env.LINK_TOKEN_ADDRESS,
        functionsRouterAddress: env.ORACLE_FUNCTIONS_ROUTER,
    });

    await subscriptionManager.initialize();

    console.log(`✅ ChainLink Subscription Manager initialized`);

    const subscriptionId: number = await subscriptionManager.createSubscription({});

    console.log(`✅ ChainLink Subscription Created id:${subscriptionId} \n`);

    const { aiPredictionV1 } = await connection.ignition.deploy(buildModule("AiPredictionV1Module", (m) => {

        const aiPredictionV1 = m.contract("AiPredictionV1", [
            m.getParameter("_ownerAddress", env.OWNER_ADDRESS),
            m.getParameter("_adminAddress", env.ADMIN_ADDRESS),

            m.getParameter("_oracleRouter", env.ORACLE_FUNCTIONS_ROUTER),
            m.getParameter("_oracleDonID", env.ORACLE_DON_ID),
            m.getParameter("_oracleSubscriptionId", subscriptionId),
            m.getParameter("_oracleAggregatorV3PriceFeed", env.ORACLE_AGGREGATOR_V3_PRICE_FEED),
            m.getParameter("_oracleCallBackGasLimit", env.ORACLE_CALLBACK_GAS_LIMIT),

            m.getParameter("_minBetAmount", parseEther(env.MIN_BET_AMOUNT.toString())),
            m.getParameter("_houseFee", env.HOUSE_FEE),
            m.getParameter("_roundMasterFee", env.ROUND_MASTER_FEE)
        ]);

        return { aiPredictionV1 };
    }),
        {
            deploymentId: hre.globalOptions.network,
            displayUi: true
        });

    const aiPredictionV1Address = await aiPredictionV1.getAddress();

    console.log(`✅ Contract deployed address: ${aiPredictionV1Address} \n`);

    console.log(`🚀 Add Contract to Subscription...`);
    const addConsumerTxReceipt = await subscriptionManager.addConsumer({
        subscriptionId,
        consumerAddress: aiPredictionV1Address,
    });
    console.log(`✅ Contract added to Subscription ID:${subscriptionId} - tx hash: ${addConsumerTxReceipt.transactionHash} \n\n`);


    console.log(`🚀 Uploading secrets to DON...`);
    const secretsManager = new SecretsManager({
        signer: v5Signer,
        functionsRouterAddress: env.ORACLE_FUNCTIONS_ROUTER,
        donId: env.ORACLE_FUN_DON_ID
    });

    await secretsManager.initialize();

    const encryptedSecretsObj = await secretsManager.encryptSecrets({
        openaiKey: env.OPEN_AI_API_KEY
    });

    const {
        version, // Secrets version number (corresponds to timestamp when encrypted secrets were uploaded to DON)
        success, // Boolean value indicating if encrypted secrets were successfully uploaded to all nodes connected to the gateway
    } = await secretsManager.uploadEncryptedSecretsToDON({
        encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
        gatewayUrls: (env.ORACLE_ENCRYPTED_SECRETS_UPLOAD_ENDPOINTS!).split(','),
        slotId: 0,
        minutesUntilExpiration: 10080,
    });

    if (!success) {
        throw Error("Mission failed")
    }

    if (success) {
        console.log(`✅ Secrets Uploaded successfully version:${version}`);
    }

}

main().catch(console.error);
