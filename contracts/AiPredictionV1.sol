// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {ChainLinkRequestFeeEstimator} from "./utils/ChainLinkRequestFeeEstimator.sol";
import {JavascriptSource} from "./utils/JavascriptSource.sol";
import {AntiContractGuard} from "./utils/AntiContractGuard.sol";
import {AdminACL} from "./utils/AdminACL.sol";

contract AiPredictionV1 is
    ReentrancyGuard,
    AntiContractGuard,
    AdminACL,
    FunctionsClient,
    JavascriptSource,
    ChainLinkRequestFeeEstimator
{
    using SafeERC20 for IERC20;

    using FunctionsRequest for FunctionsRequest.Request;
    bytes32 immutable oracleDonID;
    uint32 immutable oracleCallBackGasLimit;
    uint64 oracleSubscriptionId;
    mapping(bytes32 => uint256) public requestsLedger; // requestId -> roundId

    uint256 public houseFee; // house rate (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public houseBalance; // house treasury amount that was not claimed
    uint256 public roundMasterFee; // round creator fee (e.g. 200 = 2%, 150 = 1.50%)
    uint256 public minBetAmount; // min betting amount (wei)

    uint256 public constant MAX_OP_FEE = 1000; // 10%
    bytes32 public constant BET_OPTION_YES = keccak256(abi.encodePacked(bytes32("YES")));
    bytes32 public constant BET_OPTION_NO = keccak256(abi.encodePacked(bytes32("NO")));

    uint256 public roundIdCounter; // counter for round ids
    mapping(uint256 => Round) public rounds; // roundId -> Round
    mapping(uint256 => mapping(address => Bet)) public betsLedger; // roundId -> map(userAddress -> Bet)

    struct Bet {
        bytes32 betOption;
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
        bytes32 result;
        bytes32 oracleRequestId;
        bytes err;
    }

    event BetYes(address indexed sender, uint256 indexed roundId, uint256 amount);
    event BetNo(address indexed sender, uint256 indexed roundId, uint256 amount);

    event NewOperationFees(uint256 houseFee, uint256 roundMasterFee);
    event NewOracleSubscriptionId(uint64 newId);
    event NewMinBetAmount(uint256 minBetAmount);

    event HouseBalanceClaim(uint256 amount);
    event MasterBalanceClaim(uint256 indexed roundId, uint256 amount);
    event RewardsCalculated(
        uint256 indexed roundId,
        uint256 rewardBaseCall,
        uint256 totalVolume,
        uint256 totalFees
    );

    event OracleRequestSent(bytes32 indexed requestId, bytes response, bytes err);
    event OracleResponseReceived(bytes32 indexed requestId, bytes response, bytes err);
    event TokenRecovery(address indexed token, uint256 amount);

    /**
     * @notice Constructor
     * @param _ownerAddress: owner address
     * @param _adminAddress: admin address
     *
     * @param _minBetAmount: minimum bet amounts (in wei)
     * @param _houseFee: house fee
     * @param _roundMasterFee: round creator fee
     *
     * @param _oracleRouter: Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
     * @param _oracleDonID: DON ID - Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
     * @param _oracleCallBackGasLimit: Callback function for fulfilling a request
     * @param _oracleSubscriptionId: The ID for the Chainlink subscription
     * @param _oracleAggregatorV3PriceFeed: LINK/ETH price feed address - Check to get the price feed address for your supported network https://docs.chain.link/data-feeds/price-feeds/addresses
     */
    constructor(
        address _ownerAddress,
        address _adminAddress,
        uint256 _minBetAmount,
        uint256 _houseFee,
        uint256 _roundMasterFee,
        address _oracleRouter,
        bytes32 _oracleDonID,
        uint32 _oracleCallBackGasLimit,
        uint64 _oracleSubscriptionId,
        address _oracleAggregatorV3PriceFeed
    )
        AdminACL(_ownerAddress, _adminAddress)
        FunctionsClient(_oracleRouter)
        ChainLinkRequestFeeEstimator(_oracleRouter, _oracleAggregatorV3PriceFeed)
    {
        require(_legitFees(_houseFee, _roundMasterFee), "fee too high");
        minBetAmount = _minBetAmount;
        houseFee = _houseFee;
        roundMasterFee = _roundMasterFee;
        oracleDonID = _oracleDonID;
        oracleCallBackGasLimit = _oracleCallBackGasLimit;
        oracleSubscriptionId = _oracleSubscriptionId;
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
     * @notice Set new minBetAmount
     * @dev Callable by admin
     */
    function setMinBetAmount(uint256 _minBetAmount) external whenPaused onlyAdmin {
        require(_minBetAmount > 0, "minBetAmount too low");
        minBetAmount = _minBetAmount;
        emit NewMinBetAmount(minBetAmount);
    }

    /**
     * @notice Set new oracleSubscriptionId
     * @dev Callable by admin
     */
    function setOracleSubscriptionId(uint64 _oracleSubscriptionId) external whenPaused onlyAdmin {
        require(_oracleSubscriptionId != 0, "invalid subscription id");
        oracleSubscriptionId = _oracleSubscriptionId;
        emit NewOracleSubscriptionId(oracleSubscriptionId);
    }

    /**
     * @notice Create a new betting round
     * @param _prompt: prompt for the round
     * @param _lockTimestampByMinutes: time bet will stop at
     * @param _closeTimestampByMinutes: bet result will be released
     */
    function createRound(
        string calldata _prompt,
        uint256 _lockTimestampByMinutes,
        uint256 _closeTimestampByMinutes
    ) external payable whenNotPaused notContract nonReentrant {
        require(_lockTimestampByMinutes < _closeTimestampByMinutes, "lockTime must be less than closeTime");
        require(bytes(_prompt).length > 0, "prompt must be set");
        // uint256 roundCost = estimateEtherFee(uint256(300000)); // estimate cost with 300k gas limit
        // roundCost = (roundCost * 110) / 100; // add 10% extra gas to be sure
        // require(msg.value >= roundCost, "not enough eth to cover oracle fees");

        Round storage round = rounds[roundIdCounter];
        round.lockTimestamp = block.timestamp + (_lockTimestampByMinutes * (1 minutes));
        round.closeTimestamp = block.timestamp + (_closeTimestampByMinutes * (1 minutes));
        round.prompt = _prompt;
        round.master = msg.sender;

        // houseBalance += roundCost;

        roundIdCounter++;
    }

    /**
     * @notice Bet on Yes
     * @param roundId: roundId
     */
    function betYes(uint256 roundId) external payable nonReentrant whenNotPaused notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(betsLedger[roundId][msg.sender].amount == 0, "Can only bet once per round");
        require(_bettable(roundId), "Betting period has ended");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[roundId];
        round.totalVolume = round.totalVolume + amount;
        round.yesBetsVolume = round.yesBetsVolume + amount;

        // Update user data
        Bet storage tmp = betsLedger[roundId][msg.sender];
        tmp.betOption = BET_OPTION_YES;
        tmp.amount = amount;

        emit BetYes(msg.sender, roundId, amount);
    }

    /**
     * @notice Bet on NO
     * @param roundId: roundId
     */
    function betNo(uint256 roundId) external payable nonReentrant whenNotPaused notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(betsLedger[roundId][msg.sender].amount == 0, "Can only bet once per round");
        require(_bettable(roundId), "Betting period has ended");

        // Update round data
        uint256 amount = msg.value;
        Round storage round = rounds[roundId];
        round.totalVolume = round.totalVolume + amount;
        round.noBetsVolume = round.noBetsVolume + amount;

        // Update user data
        Bet storage tmp = betsLedger[roundId][msg.sender];
        tmp.betOption = BET_OPTION_NO;
        tmp.amount = amount;

        emit BetNo(msg.sender, roundId, amount);
    }

    /**
     * @notice End round and request result from oracle
     * @param roundId: roundId
     */
    function endRound(uint256 roundId) external nonReentrant notContract {
        require(rounds[roundId].totalVolume > 0, "not worth it");
        require(rounds[roundId].closeTimestamp < block.timestamp, "round didn't end");
        require(rounds[roundId].oracleRequestId == bytes32(0), "oracle called already");

        Round storage round = rounds[roundId];

        string[] memory args = new string[](2);
        args[0] = round.prompt;
        args[1] = Strings.toString(round.closeTimestamp);

        // send request to oracle
        bytes32 requestId = sendRequest(args);

        // update round data
        round.oracleRequestId = requestId;

        // update requestsLedger
        requestsLedger[requestId] = roundId;
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
            Bet memory bet = betsLedger[roundId][msg.sender];

            // Round validity is unknown yet
            require(round.oracleRequestId != bytes32(0), "Oracle isn't called");
            require(rounds[roundId].rewardBaseCall > 0, "Rewards aren't calculated");

            // Round valid for claiming rewards
            if (round.result == bet.betOption) {
                require(claimable(roundId, msg.sender), "You can't claim this round");
                reward += (bet.amount * round.totalVolume) / round.rewardBaseCall;
            }
            // Round invalid, refund bet amount
            else if (round.err.length > 0) {
                require(refundable(roundId, msg.sender), "You can't claim this round");
                reward += (bet.amount * round.totalVolume) / round.rewardBaseCall;
            }

            bet.claimed = true;
        }

        if (reward > 0) {
            _safeTransfer(address(msg.sender), reward);
        }
    }

    /**
     * @notice Determine if a round is valid for refunding bets
     * @param roundId: ID of the round to check
     */
    function refundable(uint256 roundId, address user) public view returns (bool) {
        Round memory round = rounds[roundId];
        Bet memory bet = betsLedger[roundId][user];
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
        Round memory round = rounds[roundId];
        Bet memory bet = betsLedger[roundId][user];
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
        require(rounds[roundId].masterBalance > 0, "you broke");

        Round storage round = rounds[roundId];
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
     * @notice Sends an HTTP request
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(string[] memory args) internal returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(javascriptSourceCode); // Initialize the request with JS code
        req.setArgs(args); // Set the arguments for the request
        // Send the request and store the reference ID
        bytes32 ref = _sendRequest(req.encodeCBOR(), oracleSubscriptionId, oracleCallBackGasLimit, oracleDonID);
        return ref;
    }

    /**
     * @notice Callback function for fulfilling a request, Either response or error parameter will be set, but never both
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        uint256 roundId = requestsLedger[requestId];

        if (err.length > 0) {
            rounds[roundId].err = err; // In case of error, store the error
        } else {
            rounds[roundId].result = keccak256(response); // Proceed with response hash it
        }

        _calculateRewards(roundId); // calculate results

        // Emit an event containing the response
        emit OracleResponseReceived(requestId, response, err);
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

        if (round.result == BET_OPTION_YES) {
            round.rewardBaseCall = round.yesBetsVolume;
        } else if (round.result == BET_OPTION_NO) {
            round.rewardBaseCall = round.noBetsVolume;
        } else {
            // round.result is empty => this happen when the oracle fail or for any other reason
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
}
