/**
 *  CanYa Coin contract
 */

pragma solidity 0.4.15;

import './lib/ERC20TokenInterface.sol';


contract CanYaCoin is ERC20TokenInterface {

    string public constant name = "CanYaCoin";
    string public constant symbol = "CAN";
    uint256 public constant decimals = 6;
    uint256 public constant totalTokens = 100000000 * (10 ** decimals);

    mapping (address => uint256) public balances;
    mapping (address => mapping (address => uint256)) public allowed;

    function CanYaCoin() {
        balances[msg.sender] = totalTokens;
    }

    function totalSupply() constant returns (uint256) {
        return totalTokens;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        if (balances[msg.sender] >= _value) {
            balances[msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(msg.sender, _to, _value);
            return true;
        }
        return false;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value) {
            balances[_from] -= _value;
            allowed[_from][msg.sender] -= _value;
            balances[_to] += _value;
            Transfer(_from, _to, _value);
            return true;
        }
        return false;
    }

    function balanceOf(address _owner) constant public returns (uint256) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

}
