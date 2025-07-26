pragma solidity ^0.8.25;

import "../ERC20Token/TokenBank.sol";
import {IERC20Callback,ExtendedERC20} from "../ExtendedERC20/ExtendedERC20.sol";

contract TokenBankV2 is TokenBank, IERC20Callback{
    ExtendedERC20 public extendedToken;

   constructor(address _tokenAddress) TokenBank(_tokenAddress){
    extendedToken = ExtendedERC20(_tokenAddress);
   }

   function tokensReceived(address sender , uint256 amount, bytes memory /* data */) external{
        require(msg.sender == address(token), "Only token contract can call");
         // 更新用户的存款记录
        balances[sender] += amount;
         // 触发存款事件
        emit Deposit(sender, amount);
   }
    
}