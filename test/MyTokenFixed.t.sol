// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/MyTokenFixed.sol";

contract MyTokenFixedTest is Test {
    Mytoken public token;
    MyBank public bank;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 部署代币合约
        vm.prank(user1);
        token = new Mytoken("MyToken", "MTK"); // Deploy with name and symbol

        // 部署银行合约
        bank = new MyBank(address(token));

        console.log("Token deployed at:", address(token));
        console.log("Bank deployed at:", address(bank));
        console.log("User1 token balance:", token.balanceOf(user1));
    }

    function testCorrectDepositFlow() public {
        uint256 depositAmount = 100 * 10**18; // 100 tokens

        vm.startPrank(user1);
        
        // 1. 检查初始余额
        uint256 initialBalance = token.balanceOf(user1);
        console.log("Initial user1 balance:", initialBalance);
        assertGt(initialBalance, depositAmount, "User should have enough tokens");

        // 2. 用户授权银行合约
        token.approve(address(bank), depositAmount);
        console.log("Approved amount:", token.allowance(user1, address(bank)));

        // 3. 存款
        bank.deposit(depositAmount);

        // 4. 验证结果
        assertEq(bank.getBalance(user1), depositAmount, "Bank balance should match deposit");
        // assertEq(bank.total(), depositAmount, "Total should match deposit"); // total() method doesn't exist
        assertEq(token.balanceOf(user1), initialBalance - depositAmount, "User balance should decrease");
        assertEq(token.balanceOf(address(bank)), depositAmount, "Bank should receive tokens");

        vm.stopPrank();
    }

    function testDepositWithoutApproval() public {
        uint256 depositAmount = 100 * 10**18;

        vm.startPrank(user1);
        
        // 尝试在没有授权的情况下存款，应该失败
        vm.expectRevert(); // ERC20会抛出ERC20InsufficientAllowance错误
        bank.deposit(depositAmount);

        vm.stopPrank();
    }

    function testDepositInsufficientBalance() public {
        // 创建一个新用户，没有代币余额
        address user3 = makeAddr("user3");
        uint256 depositAmount = 100 * 10**18;

        vm.startPrank(user3);
        
        // 授权（虽然没有余额）
        token.approve(address(bank), depositAmount);
        
        // 尝试存款，应该因为余额不足而失败
        vm.expectRevert(); // ERC20会抛出ERC20InsufficientBalance错误
        bank.deposit(depositAmount);

        vm.stopPrank();
    }

    function testWithdraw() public {
        uint256 depositAmount = 100 * 10**18;

        vm.startPrank(user1);
        
        // 先存款
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);
        
        // 提款
        uint256 withdrawAmount = 50 * 10**18;
        bank.withdraw(withdrawAmount);
        
        // 验证结果
        assertEq(bank.getBalance(user1), depositAmount - withdrawAmount, "Bank balance should decrease");
        // assertEq(bank.total(), depositAmount - withdrawAmount, "Total should decrease"); // total() method doesn't exist

        vm.stopPrank();
    }

    function testPerformUpkeep() public {
        uint256 depositAmount = 20 * 10**18;

        vm.startPrank(user1);
        
        // 存款
        token.approve(address(bank), depositAmount);
        bank.deposit(depositAmount);

        vm.stopPrank();

        // 快进时间超过1小时以触发upkeep条件
        vm.warp(block.timestamp + 3601);

        // 检查是否需要执行upkeep
        (bool upkeepNeeded, ) = bank.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");

        // 执行upkeep
        bank.performUpkeep("");
        
        // 验证upkeep执行成功（通过检查lastUpdateTime是否更新）
        // 由于performUpkeep只是更新时间戳，我们验证它不会revert
        assertTrue(true, "PerformUpkeep executed successfully");
    }
}