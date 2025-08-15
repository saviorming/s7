// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/MyTokenFixed.sol";

contract DeployMyTokenFixed is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署代币合约
        Mytoken token = new Mytoken("MyToken", "MTK"); // Deploy with name and symbol
        console.log("Token deployed at:", address(token));
        console.log("Token balance of deployer:", token.balanceOf(deployer));

        // 2. 部署银行合约
        MyBank bank = new MyBank(address(token));
        console.log("Bank deployed at:", address(bank));

        vm.stopBroadcast();

        // Demonstrate correct usage flow
        console.log("\n=== Usage Flow Demo ===");
        console.log("1. Deploy token contract: ", address(token));
        console.log("2. Deploy bank contract: ", address(bank));
        console.log("3. User should call: token.approve(bankAddress, amount)");
        console.log("4. Then call: bank.deposit(amount)");
        console.log("\n=== Important Notes ===");
        console.log("- Do NOT call bank.approve() function, this is wrong");
        console.log("- User must call approve() directly on token contract");
        console.log("- Approve address should be bank contract address");
    }
}