pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenBank{
    IERC20 public token;

    //几个每个用户存入代币的数量
    mapping(address => uint256) public balances;

    //存款事件
    event Deposit(address indexed user,uint256 amount);
    //取款事件
    event Withdraw(address indexed user,uint256 amount);

    constructor(address _tokenAddress) {
        token = IERC20(_tokenAddress);
    }

    function deposit(uint256 amount) external {
        //验证用户身上的代币数量
        require(amount >0, "Deposit amount must be greater than 0");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient token balance");
        // 存款逻辑
        token.transferFrom(msg.sender,address(this),amount);
        balances[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }
    
    function withdraw(uint256 amount) external {
        //验证用户的余额
        require(amount >0, "withdraw amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        //进行取款,将代币从当前合约转给用户
        bool success = token.transfer(msg.sender, amount);
        require(success, "Transfer failed");
        balances[msg.sender] -= amount;
        emit Withdraw(msg.sender,amount);
    }
}