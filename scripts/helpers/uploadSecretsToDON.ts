import { SecretsManager, SubscriptionManager } from "@chainlink/functions-toolkit";
import { Connections, initializeConnections } from "./initializeConnections.js";


export const uploadSecretsToDON = async (param?: Connections) => {

    const { v5Signer, env } = param ?? await initializeConnections();

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
        minutesUntilExpiration: 60,
    });

    if (!success) {
        throw Error("Mission failed")
    }

    if (success) {
        console.log(`✅ Secrets Uploaded successfully version:${version} \n`);
    }

    return { version, success }

};