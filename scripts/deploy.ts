import hre from "hardhat";
import { SubscriptionManager } from "@chainlink/functions-toolkit";
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "ethers";
import { initializeConnections } from "./helpers/initializeConnections.js";
import { subscriptionFunding } from "./helpers/subscriptionFunding.js";
import { uploadSecretsToDON } from "./helpers/uploadSecretsToDON.js";

async function main() {

    const _connections = await initializeConnections();
    const { env, connection, v5Signer } = _connections;

    const subscriptionManager = new SubscriptionManager({
        signer: v5Signer,
        linkTokenAddress: env.LINK_TOKEN_ADDRESS,
        functionsRouterAddress: env.ORACLE_FUNCTIONS_ROUTER,
    });

    console.log(`🚀 Initializing ChainLink Subscription Manager...`);
    await subscriptionManager.initialize();
    console.log(`✅ Initialized successfully \n`);


    console.log(`🚀 Creating ChainLink Subscription...`);
    const subscriptionId: number = await subscriptionManager.createSubscription({});
    console.log(`✅ ChainLink Subscription Created id:${subscriptionId} \n`);

    const { version: donHostedSecretsVersion } = await uploadSecretsToDON(_connections);

    console.log(`🚀 Deploying contract...`);
    const { aiPredictionV1 } = await connection.ignition.deploy(buildModule("AiPredictionV1Module", (m) => {

        const aiPredictionV1 = m.contract("AiPredictionV1", [
            m.getParameter("_ownerAddress", env.OWNER_ADDRESS),
            m.getParameter("_adminAddress", env.ADMIN_ADDRESS),

            m.getParameter("_minBetAmount", parseEther(env.MIN_BET_AMOUNT.toString())),
            m.getParameter("_houseFee", env.HOUSE_FEE),
            m.getParameter("_roundMasterFee", env.ROUND_MASTER_FEE),

            m.getParameter("_oracleFunctionRouter", env.ORACLE_FUNCTIONS_ROUTER),
            m.getParameter("_oracleAggregatorV3PriceFeed", env.ORACLE_AGGREGATOR_V3_PRICE_FEED),

            m.getParameter("_oracleDonID", env.ORACLE_DON_ID),

            m.getParameter("_oracleCallBackGasLimit", env.ORACLE_CALLBACK_GAS_LIMIT),
            m.getParameter("_oracleSubscriptionId", subscriptionId),

            m.getParameter("_oracleDonHostedSecretsSlotID", env.ORACLE_SECRETS_DON_HOSTED_SECRETS_SLOT_ID),

            m.getParameter("_oracleDonHostedSecretsVersion", donHostedSecretsVersion)
        ]);

        return { aiPredictionV1 };
    }),
        {
            deploymentId: hre.globalOptions.network,
            displayUi: true,
            config: { requiredConfirmations: 1 }
        });

    const aiPredictionV1Address = await aiPredictionV1.getAddress();

    console.log(`✅ Contract deployed address: ${aiPredictionV1Address} \n`);

    console.log(`🚀 Add Contract to ChainLink Subscription...`);
    const addConsumerTxReceipt = await subscriptionManager.addConsumer({
        subscriptionId,
        consumerAddress: aiPredictionV1Address,
    });
    console.log(`✅ Contract added to Subscription ID:${subscriptionId} - tx hash: ${addConsumerTxReceipt.transactionHash} \n`);

    await subscriptionFunding(subscriptionId, _connections);

    console.log(`------------Deployment-Info------------`);
    console.log(`contract address: ${aiPredictionV1Address}`)
    console.log(`secrets version:${donHostedSecretsVersion}`);
    console.log(`subscription ID: ${subscriptionId}`);

}

main().catch(console.error);
