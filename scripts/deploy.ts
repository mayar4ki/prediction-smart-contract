import hre from "hardhat";
import AiPredictionV1Module from "../ignition/modules/AiPredictionV1.js"

async function main() {
    const connection = await hre.network.connect();

    const { aiPredictionV1 } = await connection.ignition.deploy(AiPredictionV1Module, {
        deploymentId: hre.globalOptions.network,
        displayUi: true,

    });

    const address = await aiPredictionV1.getAddress();

    console.log(`✅ Contract deployed to: ${address}`);
}

main().catch(console.error);
