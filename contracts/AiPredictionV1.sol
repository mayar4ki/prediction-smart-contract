// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {AntiContractGuard} from "./utils/AntiContractGuard.sol";
import {AdminACL} from "./utils/AdminACL.sol";

contract AiPredictionV1 is ReentrancyGuard, AntiContractGuard, AdminACL {
    using SafeERC20 for IERC20;

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
    enum OracleCallStatus {
        SUCCESS,
        PENDING,
        ERROR
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
        OracleCallStatus oracleCallStatus; // default false
    }

    event BetYes(address indexed sender, uint256 indexed roundId, uint256 amount);
    event BetNo(address indexed sender, uint256 indexed roundId, uint256 amount);
    event NewOperationFees(uint256 houseFee, uint256 roundMasterFee);
    event NewMinBetAmount(uint256 minBetAmount);
    event RewardsCalculated(
        uint256 indexed roundId,
        uint256 rewardBaseCall,
        uint256 totalVolume,
        uint256 totalFees
    );
    event TokenRecovery(address indexed token, uint256 amount);
    event HouseBalanceClaim(uint256 amount);
    event MasterBalanceClaim(uint256 indexed roundId, uint256 amount);


    /**
     * @notice Constructor
     * @param _ownerAddress: owner address
     * @param _adminAddress: admin address
     * @param _minBetAmount: minimum bet amounts (in wei)
     * @param _houseFee: house fee 
     * @param _roundMasterFee: round creator fee
     */
    constructor(
        address _ownerAddress,
        address _adminAddress,
        uint256 _minBetAmount,
        uint256 _houseFee,
        uint256 _roundMasterFee
    ) AdminACL(_ownerAddress, _adminAddress) {
        require(_legitFees(_houseFee, _roundMasterFee), "Fee too high");
        minBetAmount = _minBetAmount;
        houseFee = _houseFee;
        roundMasterFee = _roundMasterFee;
    }

    /**
     * @notice Set new fees
     */
    function setOperatingFees(uint256 _houseFee, uint256 _roundMasterFee) external whenPaused onlyAdmin {
        require(_legitFees(_houseFee, _roundMasterFee), "Fee too high");
        houseFee = _houseFee;
        roundMasterFee = _roundMasterFee;
        emit NewOperationFees(_houseFee, _roundMasterFee);
    }

    /**
     * @notice Set minBetAmount
     * @dev Callable by admin
     */
    function setMinBetAmount(uint256 _minBetAmount) external whenPaused onlyAdmin {
        require(_minBetAmount > 0, "minBetAmount too low");
        minBetAmount = _minBetAmount;
        emit NewMinBetAmount(minBetAmount);
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

            // Round validity is unknown yet
            require(round.oracleCallStatus != OracleCallStatus.PENDING, "Oracle call is pending");

            // Round valid for claiming rewards
            if (round.oracleCallStatus == OracleCallStatus.SUCCESS) {
                require(claimable(roundId, msg.sender), "You can't claim this round");
                reward += (bet.amount * round.totalVolume) / round.rewardBaseCall;
            }
            // Round invalid, refund bet amount
            else if (round.oracleCallStatus == OracleCallStatus.ERROR) {
                require(refundable(roundId, msg.sender), "You can't claim this round");
                reward += (bet.amount * round.totalVolume) / round.rewardBaseCall;
            }

            bet.claimed = true;
        }

        if (reward > 0) {
            _safeTransfer(address(msg.sender), reward);
        }
    }

    function refundable(uint256 roundId, address user) public view returns (bool) {
        Round memory round = rounds[roundId];
        Bet memory bet = ledger[roundId][user];
        return
            (bet.amount > 0) &&
            (bet.claimed == false) &&
            (round.closeTimestamp < block.timestamp) &&
            (round.oracleCallStatus == OracleCallStatus.ERROR);
    }

    /**
     * @notice Determine if a round is valid for claiming rewards
     * @param roundId: ID of the round to check
     */
    function claimable(uint256 roundId, address user) public view returns (bool) {
        Round memory round = rounds[roundId];
        Bet memory bet = ledger[roundId][user];
        return
            (round.result == bet.betOption) &&
            (bet.amount > 0) &&
            (bet.claimed == false) &&
            (round.closeTimestamp < block.timestamp) &&
            (round.oracleCallStatus == OracleCallStatus.SUCCESS);
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
        require(_lockTimestampByMinutes < _closeTimestampByMinutes, "lockTime must be less than closeTime");

        Round storage round = rounds[roundIdCounter];
        round.lockTimestamp = block.timestamp + (_lockTimestampByMinutes * (1 minutes));
        round.closeTimestamp = block.timestamp + (_closeTimestampByMinutes * (1 minutes));
        round.prompt = _prompt;
        round.master = msg.sender;

        roundIdCounter++;
    }

    function endRounde(uint256 roundId) external nonReentrant notContract {
        require(rounds[roundId].totalVolume > 0, "Not worth it");

        // implement oracle 
    }

    function claimMasterBalance(uint256 roundId) external nonReentrant notContract {
        require(rounds[roundId].masterBalance > 0, "you broke");

        Round storage round = rounds[roundId];
        uint256 currentMasterBlance = round.masterBalance;
        round.masterBalance = 0;

        _safeTransfer(round.master, currentMasterBlance);
        emit MasterBalanceClaim(roundId,currentMasterBlance);
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

        if (round.result == BetOptions.Yes) {
            round.rewardBaseCall = round.yesBetsVolume;
        } else if (round.result == BetOptions.No) {
            round.rewardBaseCall = round.noBetsVolume;
        } else {
            // round.result is empty => this happen when the oracle fail
            round.rewardBaseCall = round.yesBetsVolume + round.noBetsVolume;
        }

        emit RewardsCalculated(roundId, round.rewardBaseCall, round.totalVolume, houseBalance);
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
     * @notice Determine if fees are valid
     */
    function _legitFees(uint256 _houseFee, uint256 _roundMasterFee) internal pure returns (bool) {
        return _houseFee + _roundMasterFee <= MAX_OP_FEE;
    }

    /**
     * @param to: address to transfer  to
     * @param value: amount to transfer (wei)
     */
    function _safeTransfer(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}("");
        require(success, "TransferHelper: TRANSFER_FAILED");
    }

    /**
     * @notice allows to recover tokens sent to the contract by mistake
     * @param _token: token address
     * @param _amount: token amount
     */
    function recoverToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(address(msg.sender), _amount);
        emit TokenRecovery(_token, _amount);
    }

    /**
     * @notice Claim all house balance
     */
    function claimHouseBlance() external nonReentrant onlyAdmin {
        uint256 currentHouseBalance = houseBalance;
        houseBalance = 0;
        _safeTransfer(_admin, currentHouseBalance);
        emit HouseBalanceClaim(currentHouseBalance);
    }

}
