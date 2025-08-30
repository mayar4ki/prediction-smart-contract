// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

struct FunctionsCoordinatorConfig {
    uint64 maxCallbackGasLimit;
    uint32 gasOverhead;
    uint32 requestTimeoutSeconds;
    uint64 fulfillmentFlatFeeLinkPPMTier1;
    uint64 fulfillmentFlatFeeLinkPPMTier2;
    uint64 fulfillmentFlatFeeLinkPPMTier3;
    uint64 fulfillmentFlatFeeLinkPPMTier4;
    uint64 fulfillmentFlatFeeLinkPPMTier5;
    uint24 reqsForTier2;
    uint24 reqsForTier3;
    uint24 reqsForTier4;
    uint24 reqsForTier5;
    address priceFeed;
}

interface IFunctionsCoordinator {
    function getConfig() external view returns (FunctionsCoordinatorConfig memory);
}

abstract contract ChainLinkRequestFeeEstimator {
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
     * @return linkFee The estimated LINK fee
     */
    function estimateLinkFee(uint256 callbackGasLimit) public view returns (uint256 linkFee) {
        (, int256 price, , , ) = dataFeed.latestRoundData();
        uint256 linkPerNative = uint256(price); // 1e18 format

        uint64 fulfillmentFlatFeeLinkPPMTier1 = _getFulfillmentFlatFeeLinkPPMTier1();
        uint32 gasOverhead = _getGasOverhead();

        uint256 baseFeeGwei = block.basefee / 1 gwei; // returns 30 Gwei
        uint256 overestimatedGasPrice = (baseFeeGwei * (12)) / 10; // 20% buffer e.g. 36 Gwei

        // 1 - Calculate the total gas cost (gwei): Gas price x (Gas overhead + Callback gas)
        uint256 totalGasCost = overestimatedGasPrice * (gasOverhead + callbackGasLimit);

        // 2 - Convert the gas cost to LINK using the LINK/ETH feed (e.g. 0.1 LINK/Gas) - result is in 1e18 format
        uint256 gasCostInLink = (totalGasCost * 1e9) / linkPerNative;

        // 3 - The premium fee was converted from USD to LINK at the time of the request.
        // Add this converted premium fee to get the total cost of a request:
        uint256 premiumFees = (fulfillmentFlatFeeLinkPPMTier1 * 1e12); // Convert PPM to LINK (1e6 PPM × 1e12 = 1e18) wei

        uint256 totalRequestCost = gasCostInLink + premiumFees;

        return totalRequestCost;
    }

    /**
     * @notice Estimates the ETH fee for a request
     * @param callbackGasLimit The gas limit for the callback function
     * @return ethFee The estimated ETH fee
     */
    function estimateEtherFee(uint256 callbackGasLimit) public view returns (uint256 ethFee) {
        (, int256 price, , , ) = dataFeed.latestRoundData();
        uint256 linkPerNative = uint256(price); // 1e18 format

        uint64 fulfillmentFlatFeeLinkPPMTier1 = _getFulfillmentFlatFeeLinkPPMTier1();
        uint32 gasOverhead = _getGasOverhead();

        uint256 baseFeeGwei = block.basefee / 1 gwei; // returns 30 Gwei
        uint256 overestimatedGasPrice = (baseFeeGwei * (12)) / 10; // 20% buffer e.g. 36 Gwei

        // 1 - Calculate the total gas cost (gwei): Gas price x (Gas overhead + Callback gas)
        uint256 totalGasCost = overestimatedGasPrice * (gasOverhead + callbackGasLimit);

        // 2 - Convert the gas cost to native wei - result is in 1e18 format
        uint256 gasCostInETH = totalGasCost * 1e9;

        // 3 - The premium fee was converted from USD to LINK at the time of the request.
        // Add this converted premium fee to get the total cost of a request:
        uint256 premiumFeesInLINK = (fulfillmentFlatFeeLinkPPMTier1 * 1e12); // Convert PPM to LINK (1e6 PPM × 1e12 = 1e18) wei
        uint256 premiumFeesInETH = (premiumFeesInLINK * 1e8) / linkPerNative; // ETH in wei

        uint256 totalRequestCost = gasCostInETH + premiumFeesInETH;

        return totalRequestCost;
    }

    function _getFulfillmentFlatFeeLinkPPMTier1() private view returns (uint64) {
        FunctionsCoordinatorConfig memory res = coordinator.getConfig();
        return res.fulfillmentFlatFeeLinkPPMTier1;
    }

    function _getGasOverhead() private view returns (uint32) {
        FunctionsCoordinatorConfig memory res = coordinator.getConfig();
        return res.gasOverhead;
    }
}
