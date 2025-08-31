import { SubscriptionManager } from "@chainlink/functions-toolkit";
import { Connections, initializeConnections } from "./initializeConnections.js";


export const subscriptionFunding = async (subscriptionId: number, param?: Connections) => {

    const { v5Signer, env } = param ?? await initializeConnections();

    const subscriptionManager = new SubscriptionManager({
        signer: v5Signer,
        linkTokenAddress: env.LINK_TOKEN_ADDRESS,
        functionsRouterAddress: env.ORACLE_FUNCTIONS_ROUTER,
    });

    console.log(`🚀 Initializing ChainLink Subscription Manager...`);
    await subscriptionManager.initialize();
    console.log(`✅ Initialized successfully \n`);

    console.log(`💸💸Funding Chain link subscription with ${env.ORACLE_SUBSCRIPTION_INITIAL_FUND} LINK ...`);
    const juelsAmount = BigInt(env.ORACLE_SUBSCRIPTION_INITIAL_FUND) * BigInt(10 ** 18);
    const fundSubscriptionRes = await subscriptionManager.fundSubscription({
        subscriptionId,
        juelsAmount,
    });
    console.log(`✅ subscription is funded tx: ${fundSubscriptionRes.transactionHash} \n`);

};