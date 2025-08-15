// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Defi/rebase/RebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public token;
    address public owner;
    address public user1;
    address public user2;
    
    uint256 constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿代币
    uint256 constant YEAR_IN_SECONDS = 365 days;
    uint256 constant DEFLATION_RATE = 1; // 1% 通缩率
    
    event Rebase(uint256 indexed rebaseId, uint256 newTotalSupply, uint256 timestamp);
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        token = new RebaseToken();
        
        // 给用户分发一些代币用于测试
        token.transfer(user1, 100000 * 1e18); // 10万代币
        token.transfer(user2, 50000 * 1e18);  // 5万代币
    }
    
    // ========== 基本功能测试 ==========
    
    function testInitialState() public {
        assertEq(token.name(), "DeflationaryRebaseToken");
        assertEq(token.symbol(), "DRT");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.currentCirculatingSupply(), INITIAL_SUPPLY);
        assertEq(token.rebaseCount(), 0);
        assertEq(token.scalingFactor(), 1e18);
    }
    
    function testBalanceOf() public {
        assertEq(token.balanceOf(owner), 99850000 * 1e18); // 剩余9985万
        assertEq(token.balanceOf(user1), 100000 * 1e18);
        assertEq(token.balanceOf(user2), 50000 * 1e18);
    }
    
    function testScaledBalanceOf() public {
        // 初始状态下，scaledBalance应该等于实际余额
        assertEq(token.scaledBalanceOf(owner), 99850000 * 1e18);
        assertEq(token.scaledBalanceOf(user1), 100000 * 1e18);
        assertEq(token.scaledBalanceOf(user2), 50000 * 1e18);
    }
    
    function testTransfer() public {
        uint256 transferAmount = 10000 * 1e18;
        
        vm.prank(user1);
        bool success = token.transfer(user2, transferAmount);
        
        assertTrue(success);
        assertEq(token.balanceOf(user1), 90000 * 1e18);
        assertEq(token.balanceOf(user2), 60000 * 1e18);
    }
    
    function testTransferFrom() public {
        uint256 transferAmount = 5000 * 1e18;
        
        // user1 授权给 owner
        vm.prank(user1);
        token.approve(owner, transferAmount);
        
        // owner 代表 user1 转账给 user2
        bool success = token.transferFrom(user1, user2, transferAmount);
        
        assertTrue(success);
        assertEq(token.balanceOf(user1), 95000 * 1e18);
        assertEq(token.balanceOf(user2), 55000 * 1e18);
        assertEq(token.allowance(user1, owner), 0); // 授权应该被消耗
    }
    
    function testApprove() public {
        uint256 approveAmount = 20000 * 1e18;
        
        vm.prank(user1);
        bool success = token.approve(user2, approveAmount);
        
        assertTrue(success);
        assertEq(token.allowance(user1, user2), approveAmount);
    }
    
    function testIncreaseAllowance() public {
        uint256 initialAmount = 10000 * 1e18;
        uint256 increaseAmount = 5000 * 1e18;
        
        vm.startPrank(user1);
        token.approve(user2, initialAmount);
        token.increaseAllowance(user2, increaseAmount);
        vm.stopPrank();
        
        assertEq(token.allowance(user1, user2), initialAmount + increaseAmount);
    }
    
    function testDecreaseAllowance() public {
        uint256 initialAmount = 10000 * 1e18;
        uint256 decreaseAmount = 3000 * 1e18;
        
        vm.startPrank(user1);
        token.approve(user2, initialAmount);
        token.decreaseAllowance(user2, decreaseAmount);
        vm.stopPrank();
        
        assertEq(token.allowance(user1, user2), initialAmount - decreaseAmount);
    }
    
    // ========== Rebase 机制测试 ==========
    
    function testRebaseAfterOneYear() public {
        uint256 initialSupply = token.currentCirculatingSupply();
        
        // 快进一年
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        
        vm.expectEmit(true, false, false, true);
        emit Rebase(1, (initialSupply * (100 - DEFLATION_RATE)) / 100, block.timestamp);
        
        token.rebase();
        
        assertEq(token.rebaseCount(), 1);
        assertEq(token.currentCirculatingSupply(), (initialSupply * (100 - DEFLATION_RATE)) / 100);
        
        // 检查缩放因子
        uint256 expectedScalingFactor = (1e18 * (100 - DEFLATION_RATE)) / 100;
        assertEq(token.scalingFactor(), expectedScalingFactor);
    }
    
    function testRebaseMultipleYears() public {
        uint256 initialSupply = token.currentCirculatingSupply();
        
        // 第一年
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        token.rebase();
        uint256 supplyAfterYear1 = (initialSupply * (100 - DEFLATION_RATE)) / 100;
        assertEq(token.currentCirculatingSupply(), supplyAfterYear1);
        
        // 第二年
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        token.rebase();
        uint256 supplyAfterYear2 = (supplyAfterYear1 * (100 - DEFLATION_RATE)) / 100;
        assertEq(token.currentCirculatingSupply(), supplyAfterYear2);
        assertEq(token.rebaseCount(), 2);
        
        // 第三年
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        token.rebase();
        uint256 supplyAfterYear3 = (supplyAfterYear2 * (100 - DEFLATION_RATE)) / 100;
        assertEq(token.currentCirculatingSupply(), supplyAfterYear3);
        assertEq(token.rebaseCount(), 3);
    }
    
    function testBalanceAfterRebase() public {
        uint256 user1InitialBalance = token.balanceOf(user1);
        uint256 user2InitialBalance = token.balanceOf(user2);
        
        // 快进一年并执行rebase
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        token.rebase();
        
        // 余额应该按比例减少
        uint256 expectedUser1Balance = (user1InitialBalance * (100 - DEFLATION_RATE)) / 100;
        uint256 expectedUser2Balance = (user2InitialBalance * (100 - DEFLATION_RATE)) / 100;
        
        assertEq(token.balanceOf(user1), expectedUser1Balance);
        assertEq(token.balanceOf(user2), expectedUser2Balance);
    }
    
    function testTransferAfterRebase() public {
        // 执行rebase
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        token.rebase();
        
        uint256 transferAmount = 1000 * 1e18;
        uint256 user1BalanceBefore = token.balanceOf(user1);
        uint256 user2BalanceBefore = token.balanceOf(user2);
        
        vm.prank(user1);
        token.transfer(user2, transferAmount);
        
        // 由于精度问题，使用近似相等检查
        uint256 user1BalanceAfter = token.balanceOf(user1);
        uint256 user2BalanceAfter = token.balanceOf(user2);
        
        // 允许1 wei的精度误差
        assertTrue(user1BalanceAfter >= user1BalanceBefore - transferAmount - 1 && 
                  user1BalanceAfter <= user1BalanceBefore - transferAmount + 1, "User1 balance incorrect");
        assertTrue(user2BalanceAfter >= user2BalanceBefore + transferAmount - 1 && 
                  user2BalanceAfter <= user2BalanceBefore + transferAmount + 1, "User2 balance incorrect");
    }
    
    // ========== 边界条件和错误测试 ==========
    
    function testRebaseBeforeOneYear() public {
        // 尝试在一年之前执行rebase，应该失败
        vm.warp(block.timestamp + YEAR_IN_SECONDS - 1);
        
        vm.expectRevert("DeflationaryRebaseToken: rebase not yet available");
        token.rebase();
    }
    
    function testTransferZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("Defi: transfer amount must be greater than 0");
        token.transfer(user2, 0);
    }
    
    function testTransferToZeroAddress() public {
        vm.prank(user1);
        vm.expectRevert("Defi: transfer to the zero address");
        token.transfer(address(0), 1000 * 1e18);
    }
    
    function testTransferFromZeroAddress() public {
        vm.expectRevert("Defi: transfer from the zero address");
        token.transferFrom(address(0), user2, 1000 * 1e18);
    }
    
    function testTransferInsufficientBalance() public {
        uint256 user1Balance = token.balanceOf(user1);
        
        vm.prank(user1);
        vm.expectRevert("Defi: transfer amount exceeds balance");
        token.transfer(user2, user1Balance + 1);
    }
    
    function testTransferFromInsufficientAllowance() public {
        uint256 transferAmount = 10000 * 1e18;
        
        vm.prank(user1);
        token.approve(owner, transferAmount - 1); // 授权不足
        
        vm.expectRevert("DeflationaryRebaseToken: allowance exceeded");
        token.transferFrom(user1, user2, transferAmount);
    }
    
    function testDecreaseAllowanceBelowZero() public {
        uint256 approveAmount = 5000 * 1e18;
        uint256 decreaseAmount = 6000 * 1e18;
        
        vm.startPrank(user1);
        token.approve(user2, approveAmount);
        
        vm.expectRevert("ERC20: decreased allowance below zero");
        token.decreaseAllowance(user2, decreaseAmount);
        vm.stopPrank();
    }
    
    // ========== 精度和一致性测试 ==========
    
    function testScalingFactorConsistency() public {
        // 执行多次rebase，检查缩放因子的一致性
        uint256 expectedFactor = 1e18;
        
        for (uint256 i = 0; i < 5; i++) {
            vm.warp(block.timestamp + YEAR_IN_SECONDS);
            token.rebase();
            expectedFactor = (expectedFactor * (100 - DEFLATION_RATE)) / 100;
            assertEq(token.scalingFactor(), expectedFactor);
        }
    }
    
    function testTotalSupplyConsistency() public {
        // totalSupply应该始终保持不变
        uint256 initialTotalSupply = token.totalSupply();
        
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        token.rebase();
        
        assertEq(token.totalSupply(), initialTotalSupply);
        
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        token.rebase();
        
        assertEq(token.totalSupply(), initialTotalSupply);
    }
    
    function testBalanceConsistencyAfterMultipleRebase() public {
        uint256 user1InitialBalance = token.balanceOf(user1);
        
        // 执行3次rebase
        for (uint256 i = 0; i < 3; i++) {
            vm.warp(block.timestamp + YEAR_IN_SECONDS);
            token.rebase();
        }
        
        // 计算预期余额：初始余额 * (0.99)^3
        uint256 expectedBalance = user1InitialBalance;
        for (uint256 i = 0; i < 3; i++) {
            expectedBalance = (expectedBalance * (100 - DEFLATION_RATE)) / 100;
        }
        
        assertEq(token.balanceOf(user1), expectedBalance);
    }
    
    // ========== Gas 优化测试 ==========
    
    function testGasUsageTransfer() public {
        vm.prank(user1);
        uint256 gasBefore = gasleft();
        token.transfer(user2, 1000 * 1e18);
        uint256 gasUsed = gasBefore - gasleft();
        
        // 确保gas使用在合理范围内（这个值可能需要根据实际情况调整）
        assertTrue(gasUsed < 100000, "Transfer gas usage too high");
    }
    
    function testGasUsageRebase() public {
        vm.warp(block.timestamp + YEAR_IN_SECONDS);
        
        uint256 gasBefore = gasleft();
        token.rebase();
        uint256 gasUsed = gasBefore - gasleft();
        
        // 确保rebase的gas使用在合理范围内
        assertTrue(gasUsed < 200000, "Rebase gas usage too high");
    }
}