// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;



contract AiPredictionV1 {

    address public adminAddress; // address of the admin
    address public operatorAddress; // address of the operator

    uint256 public minBetAmount; // minimum betting amount (denominated in wei)
    uint256 public treasuryFee; // treasury rate (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public treasuryAmount; // treasury amount that was not claimed

    mapping(uint256 => mapping(address => BetInfo)) public ledger;

     enum BetOptions {
        Yes,
        No
      }
    
    struct BetInfo {
        BetOptions betOn;
        uint256 amount;
        bool claimed; // default false
    }


}