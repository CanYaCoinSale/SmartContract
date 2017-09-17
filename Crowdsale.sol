/**
 *  CanYaCoin Crowdsale contract
 */

pragma solidity 0.4.15;

import './CanYaCoin.sol';
import './lib/SafeMath.sol';


contract Crowdsale {
    using SafeMath for uint256;

    CanYaCoin public CanYaCoinToken;
    bool public ended = false;
    uint8 public currentStage = 0;
    uint8 public constant FINAL_STAGE = 4;
    uint32 public startBlock;
    uint32 public endBlock;
    uint256 internal refundAmount = 0;
    uint256 public constant MAX_CONTRIBUTION = 1000 ether;
    uint256 public constant MIN_CONTRIBUTION = 0.1 ether;
    address public owner;
    address public multisig;
    mapping(uint8 => uint256) public tokensAvailable;
    mapping(uint8 => uint256) public pricePerToken;

    event LogRefund(uint256 _amount);
    event LogStageChange(uint8 _newStage);
    event LogEnded(bool _soldOut);
    event LogContribution(uint256 _amount, uint256 _tokensPurchased);

    modifier started() {
        require(block.number >= startBlock);
        _;
    }

    modifier notEnded() {
        require(!ended);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyAfterEndBlock() {
        require(block.number > endBlock);
        _;
    }

    /// @dev Sets up the amount of tokens available as per the whitepaper, as well as the
    /// corresponding prices for each stage
    /// @param _token Address of the CanYaCoin contract
    function Crowdsale(
        address _token,
        uint32 _startBlock,
        uint32 _endBlock,
        address _multisig
    ) {
        require (_token != address(0));
        require (_multisig != address(0));
        require (block.number < _startBlock);
        require (block.number < _endBlock && _startBlock < _endBlock);
        startBlock = _startBlock;
        endBlock = _endBlock;
        owner = msg.sender;
        multisig = _multisig;
        CanYaCoinToken = CanYaCoin(_token);
        tokensAvailable[0] = 9450000000000;
        tokensAvailable[1] = 11700000000000;
        tokensAvailable[2] = 11700000000000;
        tokensAvailable[3] = 11700000000000;
        tokensAvailable[4] = 11700000000000;
        pricePerToken[0] = 400000000; // 1e12 / 2500
        pricePerToken[1] = 1250000000; // 1e12 / 800
        pricePerToken[2] = 1428571428; // 1e12 / 700
        pricePerToken[3] = 1666666667; // 1e12 / 600
        pricePerToken[4] = 2000000000; // 1e12 / 500
    }

    /// @dev Fallback function, this allows users to purchase tokens by simply sending ETH to the
    /// contract; they will however need to specify a higher amount of gas than the default (21000)
    function () started notEnded payable public {
        require(msg.value >= MIN_CONTRIBUTION && msg.value <= MAX_CONTRIBUTION);
        uint256 tokensPurchased = calculateTokensPurchased(msg.value);
        reduceAvailableTokens(tokensPurchased);
        if (ended && refundAmount > 0) {
            uint256 toRefund = refundAmount;
            refundAmount = 0;
            // reentry should not be possible
            msg.sender.transfer(toRefund);
            LogRefund(toRefund);
        }
        LogContribution(msg.value, tokensPurchased);
        CanYaCoinToken.transfer(msg.sender, tokensPurchased);
        multisig.transfer(msg.value - toRefund);
    }

    /// @dev Calculates the total amount of tokens purchased depending on the amount of Ether sent to
    /// the contract, taking into account the boundaries between stages
    /// @param weiSent Amount of wei sent to the contract
    /// @return uint256 Total amount of tokens to credit to the user
    function calculateTokensPurchased(uint256 weiSent) internal returns (uint256) {
        uint256 tokensPurchasedBefore = ceil(weiSent.div(pricePerToken[currentStage]), currentStage + 1);
        uint256 tokensPurchasedAfter = tokensPurchasedBefore;
        if (tokensAvailable[currentStage] < tokensPurchasedBefore) {
            uint tokensPurchased = tokensPurchasedBefore.sub(tokensAvailable[currentStage]);
            uint weiRemaining = tokensPurchased.mul(pricePerToken[currentStage]);
            if (currentStage == FINAL_STAGE) {
                ended = true;
                LogEnded(true);
                refundAmount = weiRemaining;
                return tokensAvailable[currentStage];
            }
            uint tokensPurchasedNextStage = weiRemaining.div(pricePerToken[currentStage + 1]);
            tokensPurchasedAfter = tokensAvailable[currentStage].add(tokensPurchasedNextStage);
        }
        return tokensPurchasedAfter;
    }

    /// @dev Rounds a number up to a given precision
    /// @param a Number to round up
    /// @param m Next multiple to round up to
    /// @return r Rounded number
    function ceil(uint a, uint m) internal returns (uint r) {
        return ((a + m - 1) / m) * m;
    }

    /// @dev Increments the current stage
    function incrementStage() internal {
        currentStage++;
        LogStageChange(currentStage);
    }

    /// @dev Reduces the amount of tokens available, taking into account the boundaries between
    /// stages, also increases the current stage if we have purchased all of the current stage's
    /// available tokens
    /// @param reduceBy Amount of tokens to reduce available amount by
    function reduceAvailableTokens(uint256 reduceBy) internal {
        if (tokensAvailable[currentStage] >= reduceBy) {
            tokensAvailable[currentStage] = tokensAvailable[currentStage].sub(reduceBy);
            if (tokensAvailable[currentStage] == 0 && currentStage != FINAL_STAGE) {
                incrementStage();
            }
        } else {
            uint256 difference = reduceBy.sub(tokensAvailable[currentStage]);
            tokensAvailable[currentStage] = 0;
            incrementStage();
            tokensAvailable[currentStage] = tokensAvailable[currentStage].sub(difference);
        }
    }

    /// @dev Ends the crowdsale and withdraws any remaining tokens after the crowdsale end block
    /// @param _to Address to withdraw the tokens to
    function withdrawTokens(address _to) onlyOwner onlyAfterEndBlock public {
        require(_to != address(0));
        if (!ended) {
            LogEnded(false);
        }
        ended = true;
        CanYaCoinToken.transfer(_to, tokensAvailable[currentStage]);
        if (currentStage != 4) {
            currentStage++;
            withdrawTokens(_to);
        }
    }

}