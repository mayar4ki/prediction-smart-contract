// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ContractGuard} from "./utils/ContractGuard.sol";

contract AiPredictionV1 is ReentrancyGuard, ContractGuard, Ownable, Pausable {
    
    address public adminAddress; // address of the admin
 
    uint256 public houseFee; // house rate (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public houseBalance; // house treasury amount that was not claimed
    uint256 public roundMasterFee; // round creater fee (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public constant MAX_OP_FEE = 1000; // 10%

    uint256 public minBetAmount; // min betting amount (wei)

    //  Reconrd<RoundID,Record<Address,Bet>>
    mapping(uint256 => mapping(address => Bet)) public ledger;

    uint256 public roundIdCounter;
    // Reconrd<RoundID,Round>
    mapping(uint256 => Round) public rounds;

    enum BetOptions {
        Yes,
        No
    }

    struct Bet {
        BetOptions betOption;
        uint256 amount;
        bool claimed; // default false
    }

    struct Round {
        address master;
        uint256 masterBalance;

        string prompt;

        uint256 lockTimestamp; // time bet will stop at 
        uint256 closeTimestamp; // bet result will be released
        
        uint256 yesBetsVolume;
        uint256 noBetsVolume;
        uint256 totalVolume;

        uint256 rewardBaseCall;
  
        BetOptions result;
    }

    event BetYes(address indexed sender, uint256 indexed roundId, uint256 amount);
    event BetNo(address indexed sender, uint256 indexed roundId, uint256 amount);
    event RewardsCalculated(
    uint256 indexed roundId,
    uint256 rewardBaseCall,
    uint256 totalVolume,
    uint256 totalFees
    );


    constructor(
        address _ownerAddress,
        address _adminAddress,
        uint256 _minBetAmount,
        uint256 _houseFee,
        uint256 _roundMasterFee
    ) Ownable(_ownerAddress) {
        require((_houseFee+_roundMasterFee) <= MAX_OP_FEE, "Fee too high");

        adminAddress = _adminAddress;
        minBetAmount = _minBetAmount;
        houseFee = _houseFee;
        roundMasterFee = _roundMasterFee;

    }

    /**
     * @notice Bet on Yes
     * @param roundId: roundId
     */
    function betYes(uint256 roundId) external payable nonReentrant whenNotPaused notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[roundId][msg.sender].amount == 0, "Can only bet once per round");
        require(_bettable(roundId), "Betting period has ended");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[roundId];
        round.totalVolume = round.totalVolume + amount;
        round.yesBetsVolume = round.yesBetsVolume + amount;

        // Update user data
        Bet storage tmp = ledger[roundId][msg.sender];
        tmp.betOption = BetOptions.Yes;
        tmp.amount = amount;

        emit BetYes(msg.sender, roundId, amount);
    }

    /**
     * @notice Bet on NO
     * @param roundId: roundId
     */
    function betNo(uint256 roundId) external payable nonReentrant whenNotPaused notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[roundId][msg.sender].amount == 0, "Can only bet once per round");
        require(_bettable(roundId), "Betting period has ended");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[roundId];
        round.totalVolume = round.totalVolume + amount;
        round.noBetsVolume = round.noBetsVolume + amount;

        // Update user data
        Bet storage tmp = ledger[roundId][msg.sender];
        tmp.betOption = BetOptions.No;
        tmp.amount = amount;

        emit BetNo(msg.sender, roundId, amount);
    }

    /**
     * @notice Claim rewards for the sender for the given roundIds
     * @param roundIds: array of roundIds to claim rewards for
     */
    function claim(uint256[] calldata roundIds) external nonReentrant notContract {
        uint256 reward = 0;

        for (uint256 i = 0; i < roundIds.length; i++) {
            uint256 roundId = roundIds[i];

            Round memory round = rounds[roundId];
            Bet memory bet = ledger[roundId][msg.sender];

            if(round.result == bet.betOption){
                require(claimable(roundId,msg.sender), "You can't claim this round");
                reward += (bet.amount * round.totalVolume) / round.rewardBaseCall;
            }
            
            bet.claimed = true;
        }

        if (reward > 0) {
            _safeTransfer(address(msg.sender), reward);
        }
    }

    /**
     * @notice Create a new round
     * @param _prompt: prompt for the round
     * @param _lockTimestampByMinutes: time bet will stop at
     * @param _closeTimestampByMinutes: bet result will be released
     */
    function createRounde(
        string calldata _prompt,
        uint256 _lockTimestampByMinutes,
        uint256 _closeTimestampByMinutes
    ) external whenNotPaused notContract {
        require(_lockTimestampByMinutes < _closeTimestampByMinutes, "lockTimestamp must be less than closeTimestamp");

        Round storage round = rounds[roundIdCounter];
        round.lockTimestamp = block.timestamp + (_lockTimestampByMinutes * (1 minutes));
        round.closeTimestamp = block.timestamp + (_closeTimestampByMinutes * (1 minutes));
        round.prompt = _prompt;
        round.master = msg.sender;

        roundIdCounter++;
    }


    /**
     * @notice Determine if a round is valid for claiming rewards
     * @param roundId: ID of the round to check
     */
    function claimable(uint256 roundId, address user) public view returns (bool) {
        Round memory round = rounds[roundId];
            Bet memory bet = ledger[roundId][user];
            return (bet.amount > 0) && (bet.claimed == false) && (round.closeTimestamp < block.timestamp);
    }

    /**
     * @notice Calculate the rewards for a round
     * @param roundId: ID of the round to calculate rewards for
     */
    function _calculateRewards(uint256 roundId) internal {
        require(rounds[roundId].rewardBaseCall == 0, "Rewards calculated");
        
        Round storage round = rounds[roundId];

        houseBalance += (round.totalVolume * houseFee) / 10000;
        round.masterBalance += (round.totalVolume * roundMasterFee) / 10000;
        round.totalVolume = round.totalVolume - (houseBalance + round.masterBalance);

        if(round.result == BetOptions.Yes){
            round.rewardBaseCall = round.yesBetsVolume;
        }else if(round.result == BetOptions.No){
            round.rewardBaseCall = round.noBetsVolume;
        }else {
            round.rewardBaseCall = round.yesBetsVolume + round.noBetsVolume;
        }

        emit RewardsCalculated(roundId,round.rewardBaseCall,round.totalVolume,houseBalance);
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
