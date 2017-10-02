/**
 *  CanYaCoin Presale contract
 */

pragma solidity 0.4.15;

import './CanYaCoin.sol';
import './lib/SafeMath.sol';


contract Presale {
    using SafeMath for uint256;

    CanYaCoin public CanYaCoinToken;
    bool public ended = false;
    uint256 internal refundAmount = 0;
    uint256 constant MAX_CONTRIBUTION = 3780 ether;
    uint256 constant MIN_CONTRIBUTION = 1 ether;
    address owner;
    address constant multisig = 0xfBE55DE3383ec44c39FF839FbAF9A6d769251544;
    uint256 constant pricePerToken = 400000000;  // (wei per CAN)
    uint256 public tokensAvailable = 9450000 * (10**6);  // Whitepaper 9.45mil * 10^6

    event LogRefund(uint256 _amount);
    event LogEnded(bool _soldOut);
    event LogContribution(uint256 _amount, uint256 _tokensPurchased);

    modifier notEnded() {
        require(!ended);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /// @dev Sets up the amount of tokens available as per the whitepaper
    /// @param _token Address of the CanYaCoin contract
    function Presale(address _token) {
        require (_token != address(0));
        owner = msg.sender;
        CanYaCoinToken = CanYaCoin(_token);
    }

    /// @dev Fallback function, this allows users to purchase tokens by simply sending ETH to the
    /// contract; they will however need to specify a higher amount of gas than the default (21000)
    function () notEnded payable public {
        require(msg.value >= MIN_CONTRIBUTION && msg.value <= MAX_CONTRIBUTION);
        uint256 tokensPurchased = msg.value.div(pricePerToken);
        if (tokensPurchased > tokensAvailable) {
            ended = true;
            LogEnded(true);
            refundAmount = (tokensPurchased - tokensAvailable) * pricePerToken;
            tokensPurchased = tokensAvailable;
        }
        tokensAvailable -= tokensPurchased;
        
        //Refund the difference
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

    /// @dev Ends the crowdsale and withdraws any remaining tokens
    /// @param _to Address to withdraw the tokens to
    function withdrawTokens(address _to) onlyOwner public {
        require(_to != address(0));
        if (!ended) {
            LogEnded(false);
        }
        ended = true;
        CanYaCoinToken.transfer(_to, tokensAvailable);
    }
}
