// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IFunctionsCoordinator {
    function getConfig()
        external
        view
        returns (
            uint64 maxCallbackGasLimit,
            uint32 gasOverhead,
            uint32 requestTimeoutSeconds,
            uint64 fulfillmentFlatFeeLinkPPMTier1,
            uint64 fulfillmentFlatFeeLinkPPMTier2,
            uint64 fulfillmentFlatFeeLinkPPMTier3,
            uint64 fulfillmentFlatFeeLinkPPMTier4,
            uint64 fulfillmentFlatFeeLinkPPMTier5,
            uint24 reqsForTier2,
            uint24 reqsForTier3,
            uint24 reqsForTier4,
            uint24 reqsForTier5,
            address priceFeed
        );
}

interface IGasPriceOracle {
    function latestAnswer() external view returns (int256);
}

abstract contract ChainLinkRequestFeeEstimator {
    AggregatorV3Interface public dataFeed;
    IFunctionsCoordinator public coordinator;
    IGasPriceOracle public gasOracle;

    constructor(address _oracleRouter, address _aggregatorV3PriceFeed, address _gasPriceOracle) {
        coordinator = IFunctionsCoordinator(_oracleRouter);
        dataFeed = AggregatorV3Interface(_aggregatorV3PriceFeed);
        gasOracle = IGasPriceOracle(_gasPriceOracle);
    }

    /**
     * @notice Estimates the LINK fee for a request
     * @param overestimatedGasPriceBuffer The buffer to add to the gas price (in percentage points, e.g., 2 for 20%)
     * @return linkFee The estimated LINK fee
     */
    function estimateLinkFee(uint32 overestimatedGasPriceBuffer) external view returns (uint256 linkFee) {
        (, int256 price, , , ) = dataFeed.latestRoundData();
        uint256 linkPerNative = uint256(price); // 1e18 format

        (
            uint64 maxCallbackGasLimit,
            uint32 gasOverhead,
            ,
            ,
            ,
            ,
            ,
            uint64 fulfillmentFlatFeeLinkPPMTier5,
            ,
            ,
            ,
            ,

        ) = coordinator.getConfig();

        int256 rawPrice = gasOracle.latestAnswer(); // e.g. returns 30 Gwei
        uint256 overestimatedGasPrice = (uint256(rawPrice) * (10 + overestimatedGasPriceBuffer)) / 10; // 20% buffer e.g. 36 Gwei

        // 1 - Calculate the total gas cost (gwei): Gas price x (Gas overhead + Callback gas)
        uint256 totalGasCost = overestimatedGasPrice * (gasOverhead + maxCallbackGasLimit);

        // 2 - Convert the gas cost to LINK using the LINK/ETH feed (e.g. 0.1 LINK/Gas) - result is in 1e18 format
        uint256 gasCostInLink = (totalGasCost * 1e9) / linkPerNative;

        // 3 - The premium fee was converted from USD to LINK at the time of the request.
        // Add this converted premium fee to get the total cost of a request:
        uint256 premiumFees = (fulfillmentFlatFeeLinkPPMTier5 * 1e12); // Convert PPM to LINK (1e6 PPM × 1e12 = 1e18) wei

        uint256 totalRequestCost = gasCostInLink + premiumFees;

        return totalRequestCost;
    }

    /**
     * @notice Estimates the ETH fee for a request
     * @param overestimatedGasPriceBuffer The buffer to add to the gas price (in percentage points, e.g., 2 for 20%)
     * @return ethFee The estimated ETH fee
     */
    function estimateEtherFee(uint32 overestimatedGasPriceBuffer) external view returns (uint256 ethFee) {
        (, int256 price, , , ) = dataFeed.latestRoundData();
        uint256 linkPerNative = uint256(price); // 1e18 format

        (
            uint64 maxCallbackGasLimit,
            uint32 gasOverhead,
            ,
            ,
            ,
            ,
            ,
            uint64 fulfillmentFlatFeeLinkPPMTier5,
            ,
            ,
            ,
            ,

        ) = coordinator.getConfig();

        int256 rawPrice = gasOracle.latestAnswer(); // e.g. returns 30 Gwei
        uint256 overestimatedGasPrice = (uint256(rawPrice) * (10 + overestimatedGasPriceBuffer)) / 10; // 20% buffer e.g. 36 Gwei

        // 1 - Calculate the total gas cost (gwei): Gas price x (Gas overhead + Callback gas)
        uint256 totalGasCost = overestimatedGasPrice * (gasOverhead + maxCallbackGasLimit);

        // 2 - Convert the gas cost to native wei - result is in 1e18 format
        uint256 gasCostInETH = totalGasCost * 1e9;

        // 3 - The premium fee was converted from USD to LINK at the time of the request.
        // Add this converted premium fee to get the total cost of a request:
        uint256 premiumFeesInLINK = (fulfillmentFlatFeeLinkPPMTier5 * 1e12); // Convert PPM to LINK (1e6 PPM × 1e12 = 1e18) wei
        uint256 premiumFeesInETH = (premiumFeesInLINK * 1e8) / linkPerNative; // ETH in wei

        uint256 totalRequestCost = gasCostInETH + premiumFeesInETH;

        return totalRequestCost;
    }
}
