
# Hardhat 3 Beta Project (`node:test` and `viem`)

## AI Prediction Smart Contract
A decentralized AI prediction platform built on Ethereum using Chainlink Functions to enable secure and transparent AI-powered predictions on-chain.

## Environment Setup

The project uses environment files for configuration. A template file `.env.example` is provided with all required and optional parameters.

Required Parameters:
- `OWNER_ADDRESS` - The address that will own the contract
- `ADMIN_ADDRESS` - The address that will have admin privileges
- `ORACLE_ROUTER` - Chainlink Functions Router address for your network
- `ORACLE_DON_ID` - Chainlink DON ID for your network
- `ORACLE_SUBSCRIPTION_ID` - Chainlink Subscription ID for your network


Optional Parameters (with defaults):
- `MIN_BET_AMOUNT` - Minimum bet amount in ETH (default: 0.01 ETH)
- `HOUSE_FEE` - House fee in basis points (default: 100 = 1%)
- `ROUND_MASTER_FEE` - Round master fee in basis points (default: 200 = 2%)
- `ORACLE_CALLBACK_GAS_LIMIT` - Gas limit for oracle callback (default: 300000)

To set up your environment:
1. Copy `.env.example` to `.env.eth.sepolia` for Sepolia deployment
2. Copy `.env.example` to `.env.avax.testnet` for Avalanche Fuji deployment
3. Fill in the required parameters in the respective environment file

## Available Scripts

```bash
# Deployment Scripts
yarn deploy:sepolia      # Deploy to Ethereum Sepolia testnet
yarn deploy:avax:test    # Deploy to Avalanche Fuji testnet

# Contract Verification
yarn verify:sepolia <contract_address>     # Verify contract on Sepolia
yarn verify:avax:test <contract_address>   # Verify contract on Avalanche Fuji

# Other Utilities
yarn visualize          # Visualize the deployment graph
yarn clear             # Clear deployment artifacts and cache
```

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
