# AI Prediction Platform

A decentralized betting platform for AI predictions using Chainlink Functions for oracle services.

## Overview

This smart contract allows users to create and participate in prediction rounds where they can bet on yes/no outcomes for AI-related predictions. The platform uses Chainlink Functions to determine the outcomes, ensuring decentralized and reliable result verification.

## Features

- Create prediction rounds with customizable timeframes
- Place bets on YES/NO outcomes
- Automated result verification using Chainlink Functions
- Fair reward distribution system
- Anti-contract guard to prevent contract interactions
- Configurable house and round master fees
- Emergency pause functionality
- Token recovery for accidentally sent tokens

## Contract Details

- Contract Name: `AiPredictionV1`
- Built with Solidity >=0.8.2 <0.9.0
- Uses OpenZeppelin contracts for security features

### Key Components

- **Round System**: Users can create rounds with specific prompts and timeframes
- **Betting**: Users can bet on YES or NO outcomes
- **Oracle Integration**: Uses Chainlink Functions for result verification
- **Fee Structure**: Configurable house and round master fees
- **Security**: Implements ReentrancyGuard and AntiContractGuard

2. Fill in the environment variables in `.env`:

   Required Parameters:
   - `OWNER_ADDRESS`: The address that will own the contract
   - `ADMIN_ADDRESS`: The address that will have admin privileges
   - `ORACLE_ROUTER`: Chainlink Functions Router address for your network
   - `ORACLE_DON_ID`: Chainlink DON ID for your network
   - `PRIVATE_KEY`: Your wallet's private key (for deployment)

   Optional Parameters (with defaults):
   - `MIN_BET_AMOUNT`: Minimum bet amount in ETH (default: 0.01 ETH)
   - `HOUSE_FEE`: House fee in basis points (default: 200 = 2%)
   - `ROUND_MASTER_FEE`: Round master fee in basis points (default: 100 = 1%)
   - `ORACLE_CALLBACK_GAS_LIMIT`: Gas limit for oracle callback (default: 300000)
   - `ETHERSCAN_API_KEY`: For contract verification on Etherscan

The deployment script will:
- Validate all required environment variables
- Deploy the AiPredictionV1 contract using Hardhat Ignition
- Use environment variables for all parameters with fallback defaults
- Verify the contract on Etherscan (if ETHERSCAN_API_KEY is provided)
- Log all deployment parameters and configuration

## Contract Parameters

When deploying the contract, you'll need to provide:

- Owner address
- Admin address
- Minimum bet amount
- House fee (in basis points, e.g., 100 = 1%)
- Round master fee (in basis points, e.g., 200 = 2%)
- Oracle router address
- Oracle DON ID
- Oracle callback gas limit

## Usage

### Creating a Round

```solidity
function createRounde(
    string calldata _prompt,
    uint256 _lockTimestampByMinutes,
    uint256 _closeTimestampByMinutes
)
```

### Placing Bets

```solidity
function betYes(uint256 roundId) // For betting YES
function betNo(uint256 roundId)  // For betting NO
```

### Claiming Rewards

```solidity
function claim(uint256[] calldata roundIds)
```

## Security Features

- ReentrancyGuard for preventing reentrancy attacks
- AntiContractGuard to prevent contract interactions
- AdminACL for access control
- Pausable for emergency stops

## Fees

- House Fee: Configurable (max 10%)
- Round Master Fee: Configurable (max 10%)
- Combined fees cannot exceed 10%

## License

GPL-3.0

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request
