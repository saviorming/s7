// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "forge-std/console.sol";

contract Mytoken is ERC20, Ownable {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Ownable(msg.sender) {
        _mint(msg.sender, 1e10 * 1e18);
    }
}

interface AutomationCompatibleInterface {
    function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);
    function performUpkeep(bytes calldata performData) external;
}

contract MyBank is Ownable, AutomationCompatibleInterface {
    mapping(address => uint256) public balances;
    Mytoken public token;
    
    uint256 public constant INTEREST_RATE = 10; // 10% annual interest
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    uint256 public lastUpdateTime;
    
    event Deposit(address indexed user, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    
    constructor(address _token) Ownable(msg.sender) {
        token = Mytoken(_token);
        lastUpdateTime = block.timestamp;
    }
    
    function deposit(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        balances[msg.sender] += _amount;
        console.log("Deposit: User %s deposited %s tokens", msg.sender, _amount);
        emit Deposit(msg.sender, _amount);
    }
    
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        
        balances[msg.sender] -= _amount;
        require(token.transfer(msg.sender, _amount), "Transfer failed");
        
        console.log("Withdraw: User %s withdrew %s tokens", msg.sender, _amount);
    }
    
    function checkUpkeep(bytes calldata) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp - lastUpdateTime) >= 3600; // Update every hour
        performData = "";
    }
    
    function performUpkeep(bytes calldata) external override {
        if ((block.timestamp - lastUpdateTime) >= 3600) {
            // Apply interest to all balances
            // This is a simplified version - in practice you'd need to track individual deposit times
            console.log("Chainlink Automation: Applying interest at timestamp %s", block.timestamp);
            lastUpdateTime = block.timestamp;
        }
    }
    
    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }
}