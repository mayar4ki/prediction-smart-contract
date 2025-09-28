# Hardhat 3 Beta Project (`node:test` and `viem`)

## How the front-end look like

<p align="center">   
<img width="45%" alt="image" src="https://github.com/user-attachments/assets/43cd040d-5fef-4288-9c66-4565d77aeabe" />
<img width="45%" alt="image" src="https://github.com/user-attachments/assets/9fc8a52c-aeca-46b2-b280-b946e2d8ee66" />
</p>

<p align="center">   
<img width="45%" alt="Screenshot 2025-09-28 163937" src="https://github.com/user-attachments/assets/e5884595-fe5e-4f8f-97c4-6094c0642712" />
<img width="45%" alt="Screenshot 2025-09-28 153730" src="https://github.com/user-attachments/assets/5d172353-6c94-4fab-9590-b396ee7b06d3" />
</p>

<p align="center">   
<img width="45%" alt="Screenshot 2025-09-28 153652" src="https://github.com/user-attachments/assets/8780aa31-bb22-4216-8ac9-ddd836f65d2f" />
<img  width="45%" alt="image" src="https://github.com/user-attachments/assets/de90e818-d36d-42d7-b616-9911c276494b" />
</p>


## AI Prediction Smart Contract

A decentralized AI prediction platform built on Ethereum using Chainlink Functions to enable secure and transparent AI-powered predictions on-chain.

## Environment Setup

The project uses environment files for configuration. A template file `.env.example` is provided with all required and optional parameters.

Required Parameters:

- `OWNER_ADDRESS` - The address that will own the contract
- `ADMIN_ADDRESS` - The address that will have admin privileges
- `CHAIN_RPC_URL` - RPC URL of the network (e.g., Ethereum Sepolia)
- `CHAIN_ID` - Chain ID of the network (e.g., 11155111 for Sepolia)
- `ACCOUNT_PRIVATE_KEY` - Your wallet's private key for deployment

Chainlink Configuration:

- `ORACLE_ENCRYPTED_SECRETS_UPLOAD_ENDPOINTS` - Comma-separated list of Chainlink Functions gateway endpoints
- `ORACLE_FUNCTIONS_ROUTER` - Chainlink Functions Router address for your network
- `ORACLE_DON_ID` - Chainlink DON ID for your network (hex format)
- `ORACLE_FUN_DON_ID` - Chainlink DON ID string reference (e.g., 'fun-ethereum-sepolia-1')
- `ORACLE_AGGREGATOR_V3_PRICE_FEED` - LINK/ETH price feed address for your network
- `LINK_TOKEN_ADDRESS` - LINK token address for your network
- `ORACLE_SUBSCRIPTION_INITIAL_FUND` - Initial fund amount for Chainlink subscription in LINK

Game Configuration (with defaults):

- `MIN_BET_AMOUNT` - Minimum bet amount in ETH (default: 0.01 ETH)
- `HOUSE_FEE` - House fee in basis points (default: 100 = 1%)
- `ROUND_MASTER_FEE` - Round master fee in basis points (default: 200 = 2%)
- `ORACLE_CALLBACK_GAS_LIMIT` - Gas limit for oracle callback (default: 300000)

API Keys:

- `ETHERSCAN_API_KEY` - Your Etherscan API key for contract verification
- `OPEN_AI_API_KEY` - Your OpenAI API key for AI predictions

To set up your environment:

1. Copy `.env.example` to `.env.eth.sepolia` for Sepolia deployment
2. Copy `.env.example` to `.env.avax.testnet` for Avalanche Fuji deployment
3. Fill in the required parameters in the respective environment file

## Available Scripts

```bash
# Deployment Scripts
yarn deploy:sepolia      # Deploy to Ethereum Sepolia testnet

# Contract Verification
yarn verify:sepolia      # Verify contract on Sepolia network

# Chainlink Integration
yarn secrets:sepolia     # Upload secrets to Chainlink DON (Decentralized Oracle Network)
yarn fund:sepolia        # Fund Chainlink subscription with LINK tokens

# Development Utilities
yarn visualize          # Visualize the deployment graph
yarn clear              # Clear deployment artifacts and cache
```

All deployment-related scripts use environment variables from `.env.eth.sepolia`. Make sure to set up your environment variables before running these scripts.

## Project Overview

This project implements a smart contract system that allows users to interact with AI models through blockchain technology. It uses Chainlink Functions to securely bridge the gap between on-chain and off-chain AI computations.

Key Features:

- Smart contract-based prediction system
- Integration with Chainlink Functions for off-chain AI computations
- Admin access control system
- Anti-contract guard protection
- Secure handling of predictions and results

## Technical Stack

- Solidity >=0.8.2
- Hardhat Development Environment
- Chainlink Functions
- OpenZeppelin Contracts
  - ReentrancyGuard
  - IERC20/SafeERC20
  - AccessControl

## Smart Contracts

- `AiPredictionV1.sol`: Main prediction contract
- `AdminACL.sol`: Access control management
- `AntiContractGuard.sol`: Protection against contract-based interactions
- `JavascriptSource.sol`: Chainlink Function code

## Security Features

- ReentrancyGuard protection against reentrancy attacks
- Anti-contract measures to prevent contract-based interactions
- Admin access control for privileged operations
- Safe ERC20 token handling

## Development

### Local Setup

1. Clone the repository

```bash
git clone https://github.com/mayar4ki/prediction.git
cd prediction
```

2. Install dependencies

```bash
yarn install
```

3. Set up your environment variables

```bash
cp .env.example .env.local
```

4. Start local hardhat node

```bash
yarn hardhat node
```

5. Deploy contracts locally

```bash
yarn deploy:local
```

### Testing

Run the test suite:

```bash
yarn test
```

Run coverage report:

```bash
yarn coverage
```

## Project Structure

```
├── contracts/          # Smart contract source files
├── scripts/           # Deployment and utility scripts
├── test/             # Test files
├── ignition/         # Ignition deployment configurations
└── artifacts/        # Compiled contract artifacts
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a new branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Run tests to ensure everything works
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin feature/your-feature`)
7. Create a Pull Request

## License

Copyright © 2025 mayar4ki. All Rights Reserved.

Unauthorized copying, modification, distribution, or use of this software is strictly prohibited.
