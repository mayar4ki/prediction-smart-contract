// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {JavascriptSource} from "./JavascriptSource.sol";

abstract contract FunctionsConsumer is FunctionsClient, JavascriptSource {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 donID;
    uint32 callBackGasLimit;

    /**
     * @notice Initializes the contract with the Chainlink config
     * @param _router: Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
     * @param _donID: DON ID - Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
     */
    constructor(
        address _router,
        bytes32 _donID,
        uint32 _callBackGasLimit
    ) FunctionsClient(_router) {
        donID = _donID;
        callBackGasLimit = _callBackGasLimit;
    }

    /**
     * @notice Sends an HTTP request
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(uint64 subscriptionId, string[] calldata args) internal returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(javascriptSourceCode); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request
        // Send the request and store the reference ID
        bytes32 ref = _sendRequest(req.encodeCBOR(), subscriptionId, callBackGasLimit, donID);
        return ref;
    }
}
