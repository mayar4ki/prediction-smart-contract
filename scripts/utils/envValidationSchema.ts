import { ZeroAddress } from "ethers";
import { z } from "zod"

const ethAddress = z.string().regex(/^0x[a-fA-F0-9]{40}$/, "Invalid address")
    .refine(addr => addr !== ZeroAddress, {
        message: "Address cannot be the zero address",
    });

const donID = z.string().regex(/^0x[a-fA-F0-9]{64}$/, "Invalid don address")
    .refine(addr => addr !== ZeroAddress, {
        message: "Address cannot be the zero address",
    });;

const endpoints = z.string().refine(val => {
    return val.split(",").every(url => /^https:\/\/.+/.test(url))
}, { message: "Invalid endpoint list" });

const functionDonId = z.string().min(1);
const url = z.url();
const privateKey = z.string().regex(/^([a-fA-F0-9]{64})$/, "Invalid private key")
const apiKey = z.string().min(16, "API key too short")

export const envValidationSchema = z.object({

    // Contract Deployment Parameters
    OWNER_ADDRESS: ethAddress,
    ADMIN_ADDRESS: ethAddress,

    // Prediction Game Configuration
    MIN_BET_AMOUNT: z.coerce.number().positive(),
    HOUSE_FEE: z.coerce.number().int().min(0).max(1000),
    ROUND_MASTER_FEE: z.coerce.number().int().min(0).max(1000),

    // Chainlink Configuration
    LINK_TOKEN_ADDRESS: ethAddress,
    ORACLE_AGGREGATOR_V3_PRICE_FEED: ethAddress,

    ORACLE_FUNCTIONS_ROUTER: ethAddress,
    ORACLE_DON_ID: donID,
    ORACLE_FUN_DON_ID: functionDonId,

    ORACLE_SECRETS_ENCRYPTION_UPLOAD_ENDPOINTS: endpoints,
    ORACLE_SECRETS_DON_HOSTED_SECRETS_SLOT_ID: z.coerce.number().int().min(0),

    ORACLE_CALLBACK_GAS_LIMIT: z.coerce.number().int().positive(),
    ORACLE_SUBSCRIPTION_INITIAL_FUND: z.coerce.number().int().positive(),

    // Hardhat Configuration
    CHAIN_RPC_URL: url,
    CHAIN_ID: z.coerce.number().int().positive(),
    ACCOUNT_PRIVATE_KEY: privateKey,
    ETHERSCAN_API_KEY: apiKey,

    // OpenAI Configuration
    OPEN_AI_API_KEY: apiKey,
});