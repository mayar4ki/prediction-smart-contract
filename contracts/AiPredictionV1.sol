// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ContractGuard} from "./utils/ContractGuard.sol";

contract AiPredictionV1 is ReentrancyGuard, ContractGuard, Ownable, Pausable {
    // address of the admin
    address public adminAddress;

    uint256 public minBetAmount; // min betting amount (wei)
    uint256 public houseFee; // house rate (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public housetreasuryAmount; // house treasury amount that was not claimed

    uint256 public constant MAX_HOUSE_FEE = 1000; // 10%

    //  Reconrd<RoundID,Record<Address,BetInfo>>
    mapping(uint256 => mapping(address => BetInfo)) public ledger;

    uint256 public roundIdCounter;
    // Reconrd<RoundID,RoundInfo>
    mapping(uint256 => RoundInfo) public rounds;

    enum BetOptions {
        Yes,
        No
    }

    struct BetInfo {
        BetOptions betOption;
        uint256 amount;
        bool claimed; // default false
    }

    enum RoundResult {
        TRUE,
        INDETERMINATE,
        FALSE
    }

    struct RoundInfo {
        uint256 lockTimestamp; // bet stop at
        uint256 closeTimestamp; // bet result will be called at
        uint256 yesAmount;
        uint256 noAmount;
        uint256 totalAmount;
        string prompt;
        address createdBy;
        RoundResult result;
    }

    event BetYes(address indexed sender, uint256 indexed roundId, uint256 amount);
    event BetNo(address indexed sender, uint256 indexed roundId, uint256 amount);

    constructor(
        address initialOwner,
        address _adminAddress,
        uint256 _minBetAmount,
        uint256 _houseFee
    ) Ownable(initialOwner) {
        adminAddress = _adminAddress;
        minBetAmount = _minBetAmount;
        houseFee = _houseFee;
    }

    function betYes(uint256 roundId) external payable nonReentrant notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[roundId][msg.sender].amount == 0, "Can only bet once per round");
        require(_bettable(roundId), "Betting period has ended");

        // Update round data
        uint256 amount = msg.value;
        RoundInfo storage round = rounds[roundId];
        round.totalAmount = round.totalAmount + amount;
        round.yesAmount = round.yesAmount + amount;

        // Update user data
        BetInfo storage tmp = ledger[roundId][msg.sender];
        tmp.betOption = BetOptions.Yes;
        tmp.amount = amount;

        emit BetYes(msg.sender, roundId, amount);
    }

    function betNo(uint256 roundId) external payable nonReentrant notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[roundId][msg.sender].amount == 0, "Can only bet once per round");
        require(_bettable(roundId), "Betting period has ended");

        // Update round data
        uint256 amount = msg.value;
        RoundInfo storage round = rounds[roundId];
        round.totalAmount = round.totalAmount + amount;
        round.noAmount = round.noAmount + amount;

        // Update user data
        BetInfo storage tmp = ledger[roundId][msg.sender];
        tmp.betOption = BetOptions.No;
        tmp.amount = amount;

        emit BetNo(msg.sender, roundId, amount);
    }

    function claim(uint256[] calldata roundIds) external nonReentrant notContract {
        uint256 reward; // Initializes reward

        for (uint256 i = 0; i < roundIds.length; i++) {
            uint256 roundId = roundIds[i];

            require(ledger[roundId][msg.sender].amount > 0, "You have not bet in this round");
            require(ledger[roundId][msg.sender].claimed == false, "You have already claimed this round");
            require(rounds[roundId].closeTimestamp < block.timestamp, "Betting period has not ended");

            /*
         add value to reward 
         */
        }

        if (reward > 0) {
            _safeTransfer(address(msg.sender), reward);
        }
    }

    function createRounde(
        string calldata _promt,
        uint256 _lockTimestampByHours,
        uint256 _closeTimestampByHours
    ) external notContract {
        require(_lockTimestampByHours < _closeTimestampByHours, "lockTimestamp must be less than closeTimestamp");

        RoundInfo storage round = rounds[roundIdCounter];
        round.lockTimestamp = block.timestamp + (_lockTimestampByHours * (1 hours));
        round.closeTimestamp = block.timestamp + (_closeTimestampByHours * (1 hours));
        round.prompt = _promt;
        round.createdBy = msg.sender;

        roundIdCounter++;
    }

    /**
     * @notice Determine if a round is valid for receiving bets
     * Current timestamp must be within startTimestamp and closeTimestamp
     */
    function _bettable(uint256 roundId) internal view returns (bool) {
        return
            rounds[roundId].lockTimestamp != 0 &&
            rounds[roundId].closeTimestamp != 0 &&
            block.timestamp < rounds[roundId].lockTimestamp;
    }

    /**
     * @param to: address to transfer  to
     * @param value: amount to transfer (wei)
     */
    function _safeTransfer(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "TransferHelper: TRANSFER_FAILED");
    }
}
