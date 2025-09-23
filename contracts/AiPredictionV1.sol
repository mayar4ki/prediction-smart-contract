// SPDX-License-Identifier: UNLICENSED
// Copyright © 2025  . All Rights Reserved.

pragma solidity >=0.8.2 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BytesLib} from "./utils/BytesLib.sol";

import {ChainLinkFunction} from "./utils/ChainLinkFunction.sol";
import {AntiContractGuard} from "./utils/AntiContractGuard.sol";
import {AdminACL} from "./utils/AdminACL.sol";

contract AiPredictionV1 is ReentrancyGuard, AntiContractGuard, AdminACL, ChainLinkFunction {
    using SafeERC20 for IERC20;

    struct RequestInfo {
        bool exists;
        uint256 roundId;
    }

    mapping(bytes32 => RequestInfo) public requestsLedger; // requestId -> roundId

    uint256 public houseFee; // house rate (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public houseBalance; // house treasury amount that was not claimed
    uint256 public roundMasterFee; // round creator fee (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public minBetAmount; // min betting amount (wei)

    uint256 public constant MAX_OP_FEE = 1000; // 10%
    bytes32 public constant BET_OPTION_YES = bytes32("YES");
    bytes32 public constant BET_OPTION_NO = bytes32("NO");

    uint256 public roundIdCounter; // counter for round ids
    mapping(uint256 => Round) public roundsLedger; // roundId -> Round
    mapping(uint256 => mapping(address => BetInfo)) public betsLedger; // roundId -> map(userAddress -> Bet)

    mapping(address => uint256[]) public masterRoundIDs;

    struct BetInfo {
        bytes32 betOption;
        uint256 amount;
        bool claimed; // default false
    }

    struct Round {
        uint256 id;
        address master;
        uint256 masterBalance;
        string prompt;
        uint256 lockTimestamp; // time bet will stop at
        uint256 closeTimestamp; // bet result will be released
        uint256 yesBetsVolume;
        uint256 noBetsVolume;
        uint256 totalVolume;
        uint256 rewardBaseCall;
        bytes32 result;
        bytes32 oracleRequestId;
        bytes err;
    }

    event BetYes(address indexed sender, uint256 indexed roundId, uint256 amount);
    event BetNo(address indexed sender, uint256 indexed roundId, uint256 amount);

    event NewOperationFees(uint256 houseFee, uint256 roundMasterFee);
    event NewMinBetAmount(uint256 minBetAmount);

    event ClaimRounds(uint256[] roundIds, uint256 amount);
    event HouseBalanceClaim(uint256 amount);
    event MasterBalanceClaim(uint256 indexed roundId, uint256 amount);

    event OracleRequestSent(bytes32 indexed requestId, bytes response, bytes err);
    event OracleResponseReceived(bytes32 indexed requestId, uint256 indexed roundId, bytes response, bytes err);
    event TokenRecovery(address indexed token, uint256 amount);

    event FullFillError(bytes32 requestId, string _msg);

    /**
     * @notice Constructor
     * @param _ownerAddress: owner address
     * @param _adminAddress: admin address
     * @param _minBetAmount: minimum bet amounts (in wei)
     * @param _houseFee: house fee
     * @param _roundMasterFee: round creator fee
     * ==================== ChainLink params ====================
     * @param _oracleFunctionRouter: Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
     * @param _oracleAggregatorV3PriceFeed: LINK/ETH price feed address - Check to get the price feed address for your supported network https://docs.chain.link/data-feeds/price-feeds/addresses
     * @param _oracleDonID: DON ID - Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
     * @param _oracleCallBackGasLimit: Callback function for fulfilling a request
     * @param _oracleSubscriptionId: The ID for the Chainlink subscription
     * @param _oracleDonHostedSecretsSlotID Don hosted secrets slotId
     * @param _oracleDonHostedSecretsVersion Don hosted secrets version
     */
    constructor(
        address _ownerAddress,
        address _adminAddress,
        uint256 _minBetAmount,
        uint256 _houseFee,
        uint256 _roundMasterFee,
        address _oracleFunctionRouter,
        address _oracleAggregatorV3PriceFeed,
        bytes32 _oracleDonID,
        uint32 _oracleCallBackGasLimit,
        uint64 _oracleSubscriptionId,
        uint8 _oracleDonHostedSecretsSlotID,
        uint64 _oracleDonHostedSecretsVersion
    )
        AdminACL(_ownerAddress, _adminAddress)
        ChainLinkFunction(
            _oracleFunctionRouter,
            _oracleAggregatorV3PriceFeed,
            _oracleDonID,
            _oracleCallBackGasLimit,
            _oracleSubscriptionId,
            _oracleDonHostedSecretsSlotID,
            _oracleDonHostedSecretsVersion
        )
    {
        require(_legitFees(_houseFee, _roundMasterFee), "fee too high");
        minBetAmount = _minBetAmount;
        houseFee = _houseFee;
        roundMasterFee = _roundMasterFee;
    }

    /**
     * @notice Set new fees
     */
    function setOperatingFees(uint256 _houseFee, uint256 _roundMasterFee) external whenPaused onlyAdmin {
        require(_legitFees(_houseFee, _roundMasterFee), "fee too high");
        houseFee = _houseFee;
        roundMasterFee = _roundMasterFee;
        emit NewOperationFees(_houseFee, _roundMasterFee);
    }

    /**
     * @notice Set new minBetAmount
     * @dev Callable by admin
     */
    function setMinBetAmount(uint256 _minBetAmount) external whenPaused onlyAdmin {
        require(_minBetAmount > 0, "amount too low");
        minBetAmount = _minBetAmount;
        emit NewMinBetAmount(minBetAmount);
    }

    /**
     * @notice Set new oracleSubscriptionId
     * @dev Callable by admin
     */
    function setOracleSubscriptionId(uint64 _oracleSubscriptionId) external whenPaused onlyAdmin {
        _setOracleSubscriptionId(_oracleSubscriptionId);
    }

    /**
     * @notice Create a new betting round
     * @param _prompt: prompt for the round
     * @param _lockTimestamp: time bet will stop at (unix)
     * @param _closeTimestamp: bet result will be released (unix)
     */
    function createRound(
        string calldata _prompt,
        uint256 _lockTimestamp,
        uint256 _closeTimestamp
    ) external payable whenNotPaused notContract nonReentrant {
        require(_lockTimestamp < _closeTimestamp, "invalid timestamp");
        require(bytes(_prompt).length > 0, "prompt required");
        uint256 weiRoundCost = estimateFee() * 1e9; // estimate cost with 300k gas limit
        weiRoundCost = (weiRoundCost * 110) / 100; // add 10% extra gas to be sure
        require(msg.value >= weiRoundCost, "oracle fee not covered");

        Round storage round = roundsLedger[roundIdCounter];
        round.id = roundIdCounter;
        round.lockTimestamp = _lockTimestamp;
        round.closeTimestamp = _closeTimestamp;
        round.prompt = _prompt;
        round.master = msg.sender;
        masterRoundIDs[msg.sender].push(roundIdCounter);

        houseBalance += weiRoundCost;
        roundIdCounter++;
    }

    /**
     * @notice Bet on Yes
     * @param roundId: roundId
     */
    function betYes(uint256 roundId) external payable nonReentrant whenNotPaused notContract {
        require(msg.value >= minBetAmount, "bet is less than minBet");
        require(betsLedger[roundId][msg.sender].amount == 0, "can only bet once per round");
        require(_bettable(roundId), "bet period has ended");

        // Update round data
        uint256 amount = msg.value;
        Round storage selectedRound = roundsLedger[roundId];
        selectedRound.totalVolume = selectedRound.totalVolume + amount;
        selectedRound.yesBetsVolume = selectedRound.yesBetsVolume + amount;

        // Update user data
        BetInfo storage betInfo = betsLedger[roundId][msg.sender];
        betInfo.betOption = BET_OPTION_YES;
        betInfo.amount = amount;

        emit BetYes(msg.sender, roundId, amount);
    }

    /**
     * @notice Bet on NO
     * @param roundId: roundId
     */
    function betNo(uint256 roundId) external payable nonReentrant whenNotPaused notContract {
        require(msg.value >= minBetAmount, "bet is less than minBet");
        require(betsLedger[roundId][msg.sender].amount == 0, "can only bet once per round");
        require(_bettable(roundId), "bet period has ended");

        // Update round data
        uint256 amount = msg.value;
        Round storage selectedRound = roundsLedger[roundId];
        selectedRound.totalVolume = selectedRound.totalVolume + amount;
        selectedRound.noBetsVolume = selectedRound.noBetsVolume + amount;

        // Update user data
        BetInfo storage betInfo = betsLedger[roundId][msg.sender];
        betInfo.betOption = BET_OPTION_NO;
        betInfo.amount = amount;

        emit BetNo(msg.sender, roundId, amount);
    }

    /**
     * @notice End round and request result from oracle
     * @param roundId: roundId
     */
    function endRound(uint256 roundId) external nonReentrant notContract {
        require(roundsLedger[roundId].totalVolume > 0, "not worth it");
        require(roundsLedger[roundId].closeTimestamp < block.timestamp, "round didn't end");
        require(roundsLedger[roundId].oracleRequestId == bytes32(0), "oracle called already");

        Round storage selectedRound = roundsLedger[roundId];

        string[] memory args = new string[](2);
        args[0] = selectedRound.prompt;
        args[1] = Strings.toString(selectedRound.closeTimestamp);

        // send request to oracle
        bytes32 requestId = sendRequest(args);

        // update round data
        selectedRound.oracleRequestId = requestId;

        // update requestsLedger
        requestsLedger[requestId] = RequestInfo({roundId: roundId, exists: true});
    }

    /**
     * @notice Claim rewards for the sender for the given roundIds
     * @param roundIds: array of roundIds to claim rewards for
     */
    function claim(uint256[] calldata roundIds) external nonReentrant notContract {
        uint256 reward = 0;

        for (uint256 i = 0; i < roundIds.length; i++) {
            uint256 roundId = roundIds[i];

            Round memory round = roundsLedger[roundId];
            BetInfo storage bet = betsLedger[roundId][msg.sender];

            // Round validity is unknown yet
            require(round.oracleRequestId != bytes32(0), "oracle not called");
            require(round.rewardBaseCall > 0, "rewards not calculated");

            // Round valid for claiming rewards
            if (round.result == bet.betOption) {
                require(claimable(roundId, msg.sender), "can't claim this round");
                reward += (bet.amount * round.totalVolume) / round.rewardBaseCall;
            }
            // Round invalid, refund bet amount
            else if (round.err.length > 0) {
                require(refundable(roundId, msg.sender), "can't claim this round");
                reward += (bet.amount * round.totalVolume) / round.rewardBaseCall;
            }

            bet.claimed = true;
        }

        if (reward > 0) {
            _safeTransfer(address(msg.sender), reward);
        }

        emit ClaimRounds(roundIds, reward);
    }

    /**
     * @notice Determine if a round is valid for refunding bets
     * @param roundId: ID of the round to check
     */
    function refundable(uint256 roundId, address user) public view returns (bool) {
        Round memory round = roundsLedger[roundId];
        BetInfo memory bet = betsLedger[roundId][user];
        return
            (round.err.length > 0) &&
            (bet.amount > 0) &&
            (bet.claimed == false) &&
            (round.closeTimestamp < block.timestamp);
    }

    /**
     * @notice Determine if a round is valid for claiming rewards
     * @param roundId: ID of the round to check
     */
    function claimable(uint256 roundId, address user) public view returns (bool) {
        Round memory round = roundsLedger[roundId];
        BetInfo memory bet = betsLedger[roundId][user];
        return
            (round.err.length == 0) &&
            (round.result == bet.betOption) &&
            (bet.amount > 0) &&
            (bet.claimed == false) &&
            (round.closeTimestamp < block.timestamp);
    }

    /**
     * @notice Claim all master balance
     */
    function claimMasterBalance(uint256 roundId) external nonReentrant notContract {
        require(roundsLedger[roundId].masterBalance > 0, "no balance");

        Round storage round = roundsLedger[roundId];
        uint256 currentMasterBalance = round.masterBalance;
        round.masterBalance = 0;

        _safeTransfer(round.master, currentMasterBalance);
        emit MasterBalanceClaim(roundId, currentMasterBalance);
    }

    /**
     * @notice Claim all house balance
     */
    function claimHouseBalance() external nonReentrant onlyAdmin {
        uint256 currentHouseBalance = houseBalance;
        houseBalance = 0;
        _safeTransfer(_admin, currentHouseBalance);
        emit HouseBalanceClaim(currentHouseBalance);
    }

    /**
     * @notice Callback function for fulfilling a request, Either response or error parameter will be set, but never both
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        RequestInfo memory requestInfo = requestsLedger[requestId];

        if (requestInfo.exists == false) {
            emit FullFillError(requestId, "request not found");
            return;
        }

        Round storage round = roundsLedger[requestInfo.roundId];

        if (round.result != bytes32(0) || round.err.length != 0) {
            emit FullFillError(requestId, "already filled");
            return;
        }

        if (err.length > 0) {
            round.err = err; // In case of error, store the error
        } else {
            round.result = BytesLib.bytesToBytes32(response); // Proceed with response it
        }

        // *******calculating results********
        uint256 houseFeeAmount = (round.totalVolume * houseFee) / 10000;
        uint256 masterFeeAmount = (round.totalVolume * roundMasterFee) / 10000;

        houseBalance += houseFeeAmount;
        round.masterBalance = masterFeeAmount;

        round.totalVolume = round.totalVolume - (houseFeeAmount + masterFeeAmount);

        if (round.result == BET_OPTION_YES) {
            round.rewardBaseCall = round.yesBetsVolume;
        } else if (round.result == BET_OPTION_NO) {
            round.rewardBaseCall = round.noBetsVolume;
        } else {
            // round.result is empty => this happen when the oracle fail or for any other reason
            round.rewardBaseCall = round.yesBetsVolume + round.noBetsVolume;
        }

        // Emit an event containing the response
        emit OracleResponseReceived(requestId, requestInfo.roundId, response, err);
    }

    /**
     * @notice Determine if a round is valid for receiving bets
     * Current timestamp must be within startTimestamp and closeTimestamp
     */
    function _bettable(uint256 roundId) internal view returns (bool) {
        return
            roundsLedger[roundId].lockTimestamp != 0 &&
            roundsLedger[roundId].closeTimestamp != 0 &&
            block.timestamp < roundsLedger[roundId].lockTimestamp;
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
     * @notice Returns rounds created by master
     * @param master: master address
     * @param cursor: cursor
     * @param size: size
     */
    function getMasterRounds(
        address master,
        uint256 cursor,
        uint256 size
    ) external view returns (Round[] memory, uint256) {
        uint256 length = size;

        if (length > masterRoundIDs[master].length - cursor) {
            length = masterRoundIDs[master].length - cursor;
        }

        Round[] memory payload = new Round[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 id = masterRoundIDs[master][cursor + i];
            payload[i] = roundsLedger[id];
        }

        return (payload, cursor + length);
    }

    /**
     * @notice Returns round epochs length
     * @param master: master address
     */
    function getMasterRoundsLength(address master) external view returns (uint256) {
        return masterRoundIDs[master].length;
    }

    /**
     * @notice Returns all rounds
     * @param user: wanted user address bets
     * @param cursor: cursor
     * @param size: size
     */
    function getAllRounds(
        address user,
        uint256 cursor,
        uint256 size
    ) external view returns (Round[] memory, BetInfo[] memory, uint256) {
        uint256 length = size;

        if (length > roundIdCounter - cursor) {
            length = roundIdCounter - cursor;
        }

        Round[] memory roundsPayload = new Round[](length);
        BetInfo[] memory betsPayload = new BetInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            roundsPayload[i] = roundsLedger[cursor + i];
            betsPayload[i] = betsLedger[cursor + i][user];
        }

        return (roundsPayload, betsPayload, cursor + length);
    }
}
