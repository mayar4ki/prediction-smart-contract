import z from "zod";
import constructorArgs from "../ignition/deployments/sepolia/constructor-args.js";
import { subscriptionFunding } from "./helpers/subscriptionFunding.js";


async function main() {

    const schema = z.coerce.number().positive();

    const subId = schema.parse(constructorArgs[8])

    await subscriptionFunding(subId);
}

main().catch(console.error);
