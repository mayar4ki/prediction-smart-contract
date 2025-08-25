import { SecretsManager } from "@chainlink/functions-toolkit";

export const deploySecrets = async () => {

    const _oracleRouter = process.env.ORACLE_ROUTER;
    const _oracleDonID = process.env.ORACLE_DON_ID;
    const _openAiApiKey = process.env.OPEN_AI_API_KEY;

    if (!_oracleRouter || !_oracleDonID || !_openAiApiKey) {
        throw new Error("Missing environment variables for AiPredictionV1Module");
    }

    const secretsManager = new SecretsManager({
        signer,
        functionsRouterAddress: _oracleRouter,
        donId: _oracleDonID,
    })

    await secretsManager.initialize()

    const encryptedSecretsObj = await secretsManager.encryptSecrets({
        openaiKey: _openAiApiKey
    });

    const mySlotIdNumber = 0;
    const myExpirationTimeInMinutes = 10;

    const {
        version, // Secrets version number (corresponds to timestamp when encrypted secrets were uploaded to DON)
        success, // Boolean value indicating if encrypted secrets were successfully uploaded to all nodes connected to the gateway
    } = await secretsManager.uploadEncryptedSecretsToDON({
        encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
        gatewayUrls: ['https://exampleGatewayUrl1.com/gateway', 'https://exampleGatewayUrl2.com/gateway'],
        slotId: mySlotIdNumber,
        minutesUntilExpiration: myExpirationTimeInMinutes,
    })

    if (!success) {
        throw Error("mission failed")
    }

    if (success) {
        console.log('✅ secrets are uploaded');
    }


    return { version, success }
}