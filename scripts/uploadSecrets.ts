import { uploadSecretsToDON } from "./helpers/uploadSecretsToDON.js";

async function main() {
    await uploadSecretsToDON();
}

main().catch(console.error);
