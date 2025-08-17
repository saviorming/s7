// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @dev 模拟USDC代币，用于测试杠杆DEX
 */
contract MockUSDC is ERC20 {
    uint8 private _decimals;
    
    constructor() ERC20("Mock USDC", "USDC") {
        _decimals = 6; // USDC使用6位小数
        _mint(msg.sender, 1000000 * 10**_decimals); // 铸造100万USDC给部署者
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev 铸造代币 - 仅用于测试
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
    
    /**
     * @dev 批量铸造代币给多个地址 - 仅用于测试
     */
    function batchMint(address[] calldata recipients, uint256[] calldata amounts) external {
        require(recipients.length == amounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }
}