// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";


contract AiPredictionV1 is ReentrancyGuard {

    address public betMaker; //  admin address
    uint256 public deadline; // bet deadline

    string public question;

    uint256 public minBetAmount; // min betting amount (wei)
    uint256 public betMakerShare; // treasury rate (e.g. 10,000 = 100%, 200 = 2%, 150 = 1.50%)
    uint256 public betMakerShareAmount; // betMaker bet cut that was not claimed


    uint256 public constant BET_MAKER_MAX_SHARE = 1000; // 10%

    uint256 public totalYesAmount;
    uint256 public totalNoAmount;
    uint256 public totalAmount;


    mapping(address => BetInfo) public ledger;

    enum BetOptions {
        Yes,
        No
    }
    
    struct BetInfo {
        BetOptions betOption;
        uint256 amount;
        bool claimed; // default false
    }


    constructor(
    string memory _question,
    uint256 _betMakerShare,
    uint256 _durationInHours,
    uint256 _minBetAmount
    ){
         require(_betMakerShare <= BET_MAKER_MAX_SHARE, "admin share is too high");

         question = _question;
         betMakerShare = _betMakerShare;
         deadline = block.timestamp + (_durationInHours * 1 hours);
         minBetAmount = _minBetAmount;
         betMaker = msg.sender;
    }


    function betYes() external payable nonReentrant notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[msg.sender].amount == 0, "Can only bet once per round");
        require(block.timestamp <= deadline, "Betting period has ended");

        ledger[msg.sender] = BetInfo({
            betOption: BetOptions.Yes,
            amount: msg.value,
            claimed: false
        });

        totalYesAmount = totalYesAmount + msg.value;
        totalAmount = totalAmount + msg.value;
    }

    function betNo() external payable nonReentrant notContract {
        require(msg.value >= minBetAmount, "Bet amount must be greater than minBetAmount");
        require(ledger[msg.sender].amount == 0, "Can only bet once per round");
        require(block.timestamp <= deadline, "Betting period has ended");

        ledger[msg.sender] = BetInfo({
            betOption: BetOptions.No,
            amount: msg.value,
            claimed: false
        });

        totalNoAmount = totalNoAmount + msg.value;
        totalAmount = totalAmount + msg.value;
    }


    function claim() external nonReentrant notContract {
        require(block.timestamp > deadline, "Betting period has not ended yet");
        require(ledger[msg.sender].amount > 0, "You have not bet yet");
        require(!ledger[msg.sender].claimed, "You have already claimed your reward");

            
    }

  

    modifier notContract() {
        require(!_isContract(msg.sender), "Contract not allowed");
        require(msg.sender == tx.origin, "Proxy contract not allowed");
        _;
    }

    /**
     * @notice Returns true if `account` is a contract.
     * @param account: account address
     */
    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

}