// SPDX-License-Identifier: UNLICENSED
// Copyright © 2025  . All Rights Reserved.

pragma solidity >=0.8.2 <0.9.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

struct FunctionsCoordinatorConfig {
    uint16 maxConsumersPerSubscription; // ═════════╗ Maximum number of consumers which can be added to a single subscription. This bound ensures we are able to loop over all subscription consumers as needed, without exceeding gas limits. Should a user require more consumers, they can use multiple subscriptions.
    uint72 adminFee; //                             ║ Flat fee (in Juels of LINK) that will be paid to the Router owner for operation of the network
    bytes4 handleOracleFulfillmentSelector; //      ║ The function selector that is used when calling back to the Client contract
    uint16 gasForCallExactCheck; // ════════════════╝ Used during calling back to the client. Ensures we have at least enough gas to be able to revert if gasAmount >  63//64*gas available.
    uint32[] maxCallbackGasLimits; // ══════════════╸ List of max callback gas limits used by flag with GAS_FLAG_INDEX
    uint16 subscriptionDepositMinimumRequests; //═══╗ Amount of requests that must be completed before the full subscription balance will be released when closing a subscription account.
    uint72 subscriptionDepositJuels; // ════════════╝ Amount of subscription funds that are held as a deposit until Config.subscriptionDepositMinimumRequests are made using the subscription.
}

interface IFunctionsCoordinator {
    function getConfig() external view returns (FunctionsCoordinatorConfig memory);
}

contract ChainLinkRequestFeeEstimator {
    AggregatorV3Interface public immutable dataFeed;
    IFunctionsCoordinator public immutable coordinator;

    /**
     * @param _oracleRouter The address of the Functions Oracle Router contract
     * @param _aggregatorV3PriceFeed The address of the Chainlink Price Feed contract for LINK/ETH
     */
    constructor(address _oracleRouter, address _aggregatorV3PriceFeed) {
        coordinator = IFunctionsCoordinator(_oracleRouter);
        dataFeed = AggregatorV3Interface(_aggregatorV3PriceFeed);
    }

    /**
     * @notice Estimates the LINK fee for a request
     * @param callbackGasLimit The gas limit for the callback function
     * @return fee The estimated ETH fee
     */
    function estimateFee(uint256 callbackGasLimit) public view returns (uint256 fee) {
        uint32 fulfillmentGasPrice = _getFulfillmentGasPrice();
        uint256 gasOverheadInJuels = _getRouterAdminFees();

        (, int256 price, , , ) = dataFeed.latestRoundData(); // 1. Fetch LINK/ETH price from Chainlink feed
        uint256 linkPerEth = uint256(price); // 1e18 format

        uint256 gasOverheadInEth = (gasOverheadInJuels * linkPerEth) / 1e18; // 2. Convert LINK Juels to ETH
        uint256 gasOverheadInGwei = gasOverheadInEth * 1e9; // 3. Convert ETH to Gwei

        uint256 baseFeeGwei = block.basefee / 1 gwei; // returns 30 Gwei
        uint256 overestimatedGasPrice = (baseFeeGwei * 120) / 100; // 20% buffer e.g. 36 Gwei

        // 1 - Calculate the total gas cost (gwei): Gas price x (Gas overhead + Callback gas)
        uint256 totalGasCost = overestimatedGasPrice * (gasOverheadInGwei + callbackGasLimit);

        // 3 - The premium fee was converted from USD to LINK at the time of the request.
        // Add this converted premium fee to get the total cost of a request:
        uint256 premiumFees = uint256(fulfillmentGasPrice);

        uint256 totalRequestCost = totalGasCost + premiumFees;

        return totalRequestCost;
    }

    function _getFulfillmentGasPrice() private view returns (uint32) {
        FunctionsCoordinatorConfig memory res = coordinator.getConfig();
        return res.maxCallbackGasLimits[res.maxCallbackGasLimits.length - 1];
    }

    function _getRouterAdminFees() private view returns (uint72) {
        FunctionsCoordinatorConfig memory res = coordinator.getConfig();
        return res.adminFee;
    }
}
