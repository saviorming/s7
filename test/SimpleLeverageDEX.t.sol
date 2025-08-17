// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Defi/laverge/SimpleLeverageDEX.sol";
import "../src/Defi/laverge/MockUSDC.sol";

contract SimpleLeverageDEXTest is Test {
    SimpleLeverageDEX public dex;
    MockUSDC public usdc;
    
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public liquidator = address(0x3);
    
    uint256 public constant INITIAL_VETH_RESERVE = 1000 * 1e18; // 1000 ETH
    uint256 public constant INITIAL_VUSDC_RESERVE = 2000000 * 1e6; // 2,000,000 USDC
    uint256 public constant INITIAL_USDC_BALANCE = 100000 * 1e6; // 100,000 USDC
    
    function setUp() public {
        // 部署合约
        usdc = new MockUSDC();
        dex = new SimpleLeverageDEX(address(usdc), INITIAL_VETH_RESERVE, INITIAL_VUSDC_RESERVE);
        
        // 给用户铸造USDC
        usdc.mint(user1, INITIAL_USDC_BALANCE);
        usdc.mint(user2, 500000 * 1e6); // 给user2更多余额用于大额交易
        usdc.mint(liquidator, INITIAL_USDC_BALANCE);
        
        // 给DEX合约铸造USDC作为流动性池
        usdc.mint(address(dex), 10000000 * 1e6); // 10M USDC流动性
        
        // 用户授权DEX使用USDC
        vm.prank(user1);
        usdc.approve(address(dex), type(uint256).max);
        
        vm.prank(user2);
        usdc.approve(address(dex), type(uint256).max);
        
        vm.prank(liquidator);
        usdc.approve(address(dex), type(uint256).max);
    }
    
    function testInitialState() public {
        assertEq(dex.vETHReserve(), INITIAL_VETH_RESERVE);
        assertEq(dex.vUSDCReserve(), INITIAL_VUSDC_RESERVE);
        assertEq(dex.getCurrentPrice(), 2000 * 1e6); // 2000 USDC per ETH
    }
    
    function testOpenLongPosition() public {
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 5;
        
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        (uint256 posMargin, uint256 notional, uint256 posLeverage, int256 size, uint256 entryPrice, bool isLong) = dex.positions(user1);
        
        assertEq(posMargin, margin);
        assertEq(notional, margin * leverage);
        assertEq(posLeverage, leverage);
        assertEq(entryPrice, 2010012500); // 做多后价格上涨
        assertTrue(isLong);
        assertTrue(size > 0); // 做多仓位为正
        
        // 检查USDC余额变化
        assertEq(usdc.balanceOf(user1), INITIAL_USDC_BALANCE - margin);
        assertEq(usdc.balanceOf(address(dex)), 10000000 * 1e6 + margin); // 包含初始流动性
    }
    
    function testOpenShortPosition() public {
        uint256 margin = 1000 * 1e6; // 1000 USDC
        uint256 leverage = 3;
        
        vm.prank(user1);
        dex.openPosition(margin, leverage, false);
        
        (uint256 posMargin, uint256 notional, uint256 posLeverage, int256 size, uint256 entryPrice, bool isLong) = dex.positions(user1);
        
        assertEq(posMargin, margin);
        assertEq(notional, margin * leverage);
        assertEq(posLeverage, leverage);
        assertEq(entryPrice, 1994004500); // 做空后价格下跌
        assertFalse(isLong);
        assertTrue(size < 0); // 做空仓位为负
    }
    
    function testCannotOpenMultiplePositions() public {
        uint256 margin = 1000 * 1e6;
        
        vm.startPrank(user1);
        dex.openPosition(margin, 2, true);
        
        vm.expectRevert("Position already exists");
        dex.openPosition(margin, 3, false);
        vm.stopPrank();
    }
    
    function testInvalidLeverage() public {
        uint256 margin = 1000 * 1e6;
        
        vm.prank(user1);
        vm.expectRevert("Leverage must be between 1 and 10");
        dex.openPosition(margin, 0, true);
        
        vm.prank(user1);
        vm.expectRevert("Leverage must be between 1 and 10");
        dex.openPosition(margin, 11, true);
    }
    
    function testClosePositionWithProfit() public {
        uint256 margin = 1000 * 1e6;
        uint256 leverage = 2;
        
        // 开多仓
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        // 模拟价格上涨 - 通过另一个用户开多仓来推高价格
        vm.prank(user2);
        dex.openPosition(5000 * 1e6, 2, true); // 大额多仓增加vUSDCReserve，但由于K恒定，vETHReserve减少，推高价格
        
        // 检查PnL
        int256 pnl = dex.calculatePnL(user1);
        assertTrue(pnl > 0, "Should have profit");
        
        uint256 balanceBefore = usdc.balanceOf(user1);
        
        // 平仓
        vm.prank(user1);
        dex.closePosition();
        
        uint256 balanceAfter = usdc.balanceOf(user1);
        
        // 检查仓位已清除
        (uint256 posMarginAfter,,,,, ) = dex.positions(user1);
        assertEq(posMarginAfter, 0);
        
        // 检查余额增加
        assertTrue(balanceAfter > balanceBefore);
    }
    
    function testClosePositionWithLoss() public {
        uint256 margin = 1000 * 1e6;
        uint256 leverage = 2;
        
        // 开多仓
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        // 模拟价格下跌 - 通过另一个用户开空仓来压低价格
        vm.prank(user2);
        dex.openPosition(5000 * 1e6, 2, false); // 大额空仓减少vUSDCReserve，增加vETHReserve，压低价格
        
        // 检查PnL
        int256 pnl = dex.calculatePnL(user1);
        assertTrue(pnl < 0, "Should have loss");
        
        uint256 balanceBefore = usdc.balanceOf(user1);
        
        // 平仓
        vm.prank(user1);
        dex.closePosition();
        
        uint256 balanceAfter = usdc.balanceOf(user1);
        
        // 检查仓位已清除
        (uint256 posMarginAfterLiq,,,,, ) = dex.positions(user1);
        assertEq(posMarginAfterLiq, 0);
        
        // 检查余额变化（应该少于初始保证金）
        assertTrue(balanceAfter < balanceBefore + margin);
    }
    
    function testCannotCloseNonExistentPosition() public {
        vm.prank(user1);
        vm.expectRevert("No open position");
        dex.closePosition();
    }
    
    function testLiquidation() public {
        uint256 margin = 10 * 1e6;  // 进一步减少保证金
        uint256 leverage = 5; // 增加杠杆
        
        // user1开高杠杆多仓
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        // 模拟价格大幅下跌 - 多次开空仓
        vm.prank(user2);
        dex.openPosition(50000 * 1e6, 10, false); // 第一次大额空仓
        
        // 继续推低价格
        address user3 = makeAddr("user3");
        usdc.mint(user3, 500000 * 1e6);
        vm.prank(user3);
        usdc.approve(address(dex), type(uint256).max);
        vm.prank(user3);
        dex.openPosition(50000 * 1e6, 10, false); // 第二次大额空仓
        
        // 检查PnL和清算条件
        int256 pnl = dex.calculatePnL(user1);
        console.log("PnL:", pnl);
        console.log("Margin:", margin);
        console.log("Liquidation threshold (10%):", (margin * 10) / 100);
        
        // 检查仓位信息
        (uint256 posMargin, uint256 notional, uint256 posLeverage, int256 size, uint256 entryPrice, bool isLong) = dex.positions(user1);
        console.log("Position notional:", notional);
        console.log("Position size:", uint256(size));
        console.log("Entry price:", entryPrice);
        console.log("Current price:", dex.getCurrentPrice());
        console.log("Current vUSDCReserve:", dex.vUSDCReserve());
        console.log("Current vETHReserve:", dex.vETHReserve());
        
        // 检查是否可以清算
        console.log("Can liquidate:", dex.canLiquidate(user1));
        console.log("Loss (USDC):", uint256(-pnl));
        console.log("Threshold (USDC):", (margin * 10) / 100);
        console.log("PnL < 0:", pnl < 0);
        console.log("Loss >= Threshold:", uint256(-pnl) >= (margin * 10) / 100);
        assertTrue(dex.canLiquidate(user1), "Position should be liquidatable");
        
        uint256 liquidatorBalanceBefore = usdc.balanceOf(liquidator);
        
        // 执行清算
        vm.prank(liquidator);
        dex.liquidatePosition(user1);
        
        // 检查仓位已清除
        (uint256 posMarginCleared,,,,, ) = dex.positions(user1);
        assertEq(posMarginCleared, 0);
        
        // 检查清算者获得奖励
        assertEq(usdc.balanceOf(liquidator) - liquidatorBalanceBefore, (margin * dex.LIQUIDATION_REWARD()) / 100);
    }
    
    function testCannotLiquidateOwnPosition() public {
        uint256 margin = 1000 * 1e6;
        
        vm.prank(user1);
        dex.openPosition(margin, 10, true);
        
        vm.prank(user1);
        vm.expectRevert("Cannot liquidate own position");
        dex.liquidatePosition(user1);
    }
    
    function testCannotLiquidateHealthyPosition() public {
        uint256 margin = 1000 * 1e6;
        
        vm.prank(user1);
        dex.openPosition(margin, 2, true); // 低杠杆
        
        vm.prank(liquidator);
        vm.expectRevert("Position cannot be liquidated");
        dex.liquidatePosition(user1);
    }
    
    function testPriceImpact() public {
        uint256 initialPrice = dex.getCurrentPrice();
        
        // 大额多仓应该推高价格
        vm.prank(user1);
        dex.openPosition(5000 * 1e6, 2, true);
        
        uint256 priceAfterLong = dex.getCurrentPrice();
        assertTrue(priceAfterLong > initialPrice, "Price should increase after long position");
        
        // 大额空仓应该压低价格
        vm.prank(user2);
        dex.openPosition(5000 * 1e6, 2, false);
        
        uint256 priceAfterShort = dex.getCurrentPrice();
        assertTrue(priceAfterShort < priceAfterLong, "Price should decrease after short position");
    }
    
    function testEvents() public {
        uint256 margin = 1000 * 1e6;
        uint256 leverage = 3;
        
        // 测试开仓事件
        vm.expectEmit(true, false, false, false);
        emit SimpleLeverageDEX.PositionOpened(user1, margin, leverage, true, 0, 0);
        
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        // 测试平仓事件
        vm.expectEmit(true, false, false, false);
        emit SimpleLeverageDEX.PositionClosed(user1, 0, 0);
        
        vm.prank(user1);
        dex.closePosition();
    }
    
    function testCalculatePnLAccuracy() public {
        uint256 margin = 1000 * 1e6;
        uint256 leverage = 2;
        
        // 开多仓
        vm.prank(user1);
        dex.openPosition(margin, leverage, true);
        
        uint256 entryPrice = dex.getCurrentPrice();
        
        // 记录初始PnL（应该为0）
        int256 initialPnL = dex.calculatePnL(user1);
        assertEq(initialPnL, 0, "Initial PnL should be 0");
        
        // 模拟价格变化
        vm.prank(user2);
        dex.openPosition(1000 * 1e6, 2, false);
        
        uint256 newPrice = dex.getCurrentPrice();
        int256 pnl = dex.calculatePnL(user1);
        
        // 验证PnL计算逻辑
        if (newPrice > entryPrice) {
            assertTrue(pnl > 0, "PnL should be positive when price increases for long position");
        } else {
            assertTrue(pnl < 0, "PnL should be negative when price decreases for long position");
        }
    }
}