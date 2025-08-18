// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Defi/options/CallOptionToken.sol";
import "../src/Defi/options/MockUSDT.sol";

/**
 * @title DeployCallOption
 * @dev 部署看涨期权Token和USDT模拟合约的脚本
 */
contract DeployCallOption is Script {
    // 部署参数
    uint256 public constant STRIKE_PRICE = 2000 ether;     // 行权价格: 2000 ETH
    uint256 public constant UNDERLYING_PRICE = 1800 ether; // 创建时ETH价格: 1800 ETH
    uint256 public constant EXPIRATION_DAYS = 7;           // 7天后到期
    uint256 public constant INITIAL_USDT_SUPPLY = 1000000; // 100万 USDT
    
    function run() external {
        // 获取部署者私钥
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", deployer);
        console.log("Account balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 计算到期时间
        uint256 expirationTime = block.timestamp + (EXPIRATION_DAYS * 1 days);
        
        // 部署USDT模拟合约
        MockUSDT usdt = new MockUSDT(INITIAL_USDT_SUPPLY);
        
        // 部署看涨期权Token合约
        CallOptionToken optionToken = new CallOptionToken(
            "ETH Call Option 2000",
            "ETH-CALL-2000",
            STRIKE_PRICE,
            expirationTime,
            UNDERLYING_PRICE,
            address(usdt)
        );
        
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("\n=== Deployment Complete ===");
        console.log("CallOptionToken deployed to:", address(optionToken));
        console.log("MockUSDT deployed to:", address(usdt));
        console.log("\n=== Option Parameters ===");
        console.log("Strike Price:", STRIKE_PRICE / 1e18, "ETH");
        console.log("Underlying Price:", UNDERLYING_PRICE / 1e18, "ETH");
        console.log("Expiration Time:", expirationTime);
        console.log("Expiration Date:", formatTimestamp(expirationTime));
        console.log("\n=== Contract Addresses ===");
        console.log("Option Token:", address(optionToken));
        console.log("USDT Token:", address(usdt));
        
        // 验证部署
        verifyDeployment(optionToken, usdt);
    }
    
    /**
     * @dev 验证部署是否成功
     */
    function verifyDeployment(CallOptionToken optionToken, MockUSDT usdt) internal view {
        console.log("\n=== Deployment Verification ===");
        
        // 验证期权Token
        require(optionToken.strikePrice() == STRIKE_PRICE, "Strike price mismatch");
        require(optionToken.underlyingPrice() == UNDERLYING_PRICE, "Underlying price mismatch");
        require(optionToken.totalSupply() == 0, "Initial supply should be 0");
        console.log("[OK] CallOptionToken verification passed");
        
        // 验证USDT
        require(usdt.totalSupply() == INITIAL_USDT_SUPPLY * 10**usdt.decimals(), "USDT supply mismatch");
        require(usdt.decimals() == 6, "USDT decimals should be 6");
        console.log("[OK] MockUSDT verification passed");
        
        console.log("\n All contracts deployed and verified successfully!");
    }
    
    /**
     * @dev 格式化时间戳为可读格式
     */
    function formatTimestamp(uint256 timestamp) internal pure returns (string memory) {
        // 简单的时间格式化，实际项目中可以使用更复杂的库
        return string(abi.encodePacked("Timestamp: ", vm.toString(timestamp)));
    }
}

/**
 * @title DeployAndDemo
 * @dev 部署合约并演示基本功能
 */
contract DeployAndDemo is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 部署合约
        uint256 expirationTime = block.timestamp + 7 days;
        MockUSDT usdt = new MockUSDT(1000000);
        
        CallOptionToken optionToken = new CallOptionToken(
            "ETH Call Option 2000",
            "ETH-CALL-2000",
            2000 ether,
            expirationTime,
            1800 ether,
            address(usdt)
        );
        
        // 演示功能
        console.log("\n=== Demo Option Issuance ===");
        
        // 发行期权（需要发送ETH）
        uint256 ethToDeposit = 5 ether;
        optionToken.issueOptions{value: ethToDeposit}();
        
        console.log("Option tokens issued:", optionToken.balanceOf(deployer));
        console.log("Contract ETH balance:", address(optionToken).balance);
        
        // 铸造一些USDT给部署者
        usdt.mint(deployer, 10000); // 1万 USDT
        console.log("USDT balance:", usdt.balanceOf(deployer));
        
        vm.stopBroadcast();
        
        console.log("\n=== Demo Complete ===");
        console.log("Option Token address:", address(optionToken));
        console.log("USDT address:", address(usdt));
    }
}