// SPDX-License-Identifier: UNLICENSED
// Copyright © 2025  . All Rights Reserved.

pragma solidity >=0.8.2 <0.9.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import "./InlineJavaScript.sol";

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

abstract contract ChainLinkFunction is FunctionsClient {
    AggregatorV3Interface public immutable dataFeed;
    IFunctionsCoordinator public immutable coordinator;

    bytes32 public immutable donID;
    uint32 public immutable callBackGasLimit;
    uint64 public subscriptionId;

    uint8 public immutable donHostedSecretsSlotID;
    uint64 public immutable donHostedSecretsVersion;

    using FunctionsRequest for FunctionsRequest.Request;

    event NewOracleSubscriptionId(uint64 newId);

    /**
     * @param _functionRouter The address of the Functions Oracle Router contract
     * @param _aggregatorV3PriceFeed The address of the Chainlink Price Feed contract for LINK/ETH
     * @param _donID: DON ID - Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
     * @param _callBackGasLimit: Callback function for fulfilling a request
     * @param _subscriptionId: The ID for the Chainlink subscription
     * @param _donHostedSecretsSlotID Don hosted secrets slotId
     * @param _donHostedSecretsVersion Don hosted secrets version
     */
    constructor(
        address _functionRouter,
        address _aggregatorV3PriceFeed,
        bytes32 _donID,
        uint32 _callBackGasLimit,
        uint64 _subscriptionId,
        uint8 _donHostedSecretsSlotID,
        uint64 _donHostedSecretsVersion
    ) FunctionsClient(_functionRouter) {
        coordinator = IFunctionsCoordinator(_functionRouter);
        dataFeed = AggregatorV3Interface(_aggregatorV3PriceFeed);

        donID = _donID;
        callBackGasLimit = _callBackGasLimit;
        subscriptionId = _subscriptionId;

        donHostedSecretsSlotID = _donHostedSecretsSlotID;
        donHostedSecretsVersion = _donHostedSecretsVersion;
    }

    /**
     * @notice Set new oracleSubscriptionId
     * @dev Callable by admin
     */
    function _setOracleSubscriptionId(uint64 _oracleSubscriptionId) internal virtual {
        require(_oracleSubscriptionId != 0, "invalid id");
        subscriptionId = _oracleSubscriptionId;
        emit NewOracleSubscriptionId(subscriptionId);
    }

    /**
     * @notice Sends an HTTP request
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(string[] memory args) internal returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;

        req.initializeRequestForInlineJavaScript(InlineJavaScript.code); // Initialize the request with JS code

        req.setArgs(args); // Set the arguments for the request

        req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);

        // Send the request and store the reference ID
        bytes32 ref = _sendRequest(req.encodeCBOR(), subscriptionId, callBackGasLimit, donID);
        return ref;
    }

    /**
     * @notice Estimates the LINK fee for a request
     * @return fee The estimated ETH fee
     */
    function estimateFee() public view returns (uint256 fee) {
        uint32 fulfillmentGasPrice = _getFulfillmentGasPrice();
        uint256 gasOverheadInJuels = _getRouterAdminFees();

        (, int256 price, , , ) = dataFeed.latestRoundData(); // 1. Fetch LINK/ETH price from Chainlink feed
        uint256 linkPerEth = uint256(price); // 1e18 format

        uint256 gasOverheadInEth = (gasOverheadInJuels * linkPerEth) / 1e18; // 2. Convert LINK Juels to ETH
        uint256 gasOverheadInGwei = gasOverheadInEth * 1e9; // 3. Convert ETH to Gwei

        uint256 baseFeeGwei = (block.basefee > 0 ? block.basefee : tx.gasprice) / 1e9;
        uint256 overestimatedGasPrice = (baseFeeGwei * 120) / 100; // 20% buffer e.g. 36 Gwei

        // 1 - Calculate the total gas cost (gwei): Gas price x (Gas overhead + Callback gas)
        uint256 totalGasCost = overestimatedGasPrice * (gasOverheadInGwei + callBackGasLimit);

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
