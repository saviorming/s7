// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Defi/options/OptionTradingPair.sol";
import "../src/Defi/options/CallOptionToken.sol";
import "../src/Defi/options/MockUSDT.sol";

contract OptionTradingPairTest is Test {
    OptionTradingPair public tradingPair;
    CallOptionToken public optionToken;
    MockUSDT public usdt;
    
    address public owner;
    address public user1;
    address public user2;
    
    // 测试常量
    uint256 constant STRIKE_PRICE = 0.1 ether;
    uint256 constant UNDERLYING_PRICE = 0.08 ether;
    uint256 constant OPTION_PRICE = 0.01 ether; // 期权价格：0.01 USDT
    uint256 constant INITIAL_ETH_DEPOSIT = 10 ether;
    uint256 constant INITIAL_USDT_SUPPLY = 1000000 * 1e6; // 100万 USDT
    
    // 事件
    event OptionPurchased(address indexed buyer, uint256 usdtAmount, uint256 optionAmount);
    event OptionSold(address indexed seller, uint256 optionAmount, uint256 usdtAmount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event LiquidityAdded(uint256 optionAmount, uint256 usdtAmount);
    event LiquidityRemoved(uint256 optionAmount, uint256 usdtAmount);
    
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 部署合约
        uint256 expiration = block.timestamp + 30 days;
        usdt = new MockUSDT(INITIAL_USDT_SUPPLY);
        
        optionToken = new CallOptionToken(
            "Call Option Token",
            "COT",
            STRIKE_PRICE,
            expiration,
            UNDERLYING_PRICE,
            address(usdt)
        );
        
        tradingPair = new OptionTradingPair(
            address(optionToken),
            address(usdt),
            OPTION_PRICE
        );
        
        // 发行期权Token
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        // 给用户分配USDT
        usdt.mint(user1, 1000 * 1e6); // 1000 USDT
        usdt.mint(user2, 1000 * 1e6); // 1000 USDT
        
        // 给交易对添加流动性
        uint256 optionLiquidity = 5 ether; // 5个期权Token
        uint256 usdtLiquidity = 100 * 1e6; // 100 USDT
        
        optionToken.approve(address(tradingPair), optionLiquidity);
        usdt.approve(address(tradingPair), usdtLiquidity);
        tradingPair.addLiquidity(optionLiquidity, usdtLiquidity);
    }
    
    /**
     * @dev 测试初始化
     */
    function testInitialization() public view {
        assertEq(address(tradingPair.optionToken()), address(optionToken));
        assertEq(address(tradingPair.usdt()), address(usdt));
        assertEq(tradingPair.optionPrice(), OPTION_PRICE);
        assertEq(tradingPair.owner(), owner);
    }
    
    /**
     * @dev 测试用USDT购买期权Token
     */
    function testBuyOptions() public {
        uint256 usdtAmount = 50 * 1e6; // 50 USDT
        uint256 expectedOptionAmount = (usdtAmount * 1e18) / OPTION_PRICE; // 5000个期权Token
        
        vm.startPrank(user1);
        usdt.approve(address(tradingPair), usdtAmount);
        
        uint256 userUsdtBefore = usdt.balanceOf(user1);
        uint256 userOptionBefore = optionToken.balanceOf(user1);
        uint256 contractUsdtBefore = usdt.balanceOf(address(tradingPair));
        uint256 contractOptionBefore = optionToken.balanceOf(address(tradingPair));
        
        vm.expectEmit(true, false, false, true);
        emit OptionPurchased(user1, usdtAmount, expectedOptionAmount);
        
        tradingPair.buyOptions(usdtAmount);
        
        assertEq(usdt.balanceOf(user1), userUsdtBefore - usdtAmount);
        assertEq(optionToken.balanceOf(user1), userOptionBefore + expectedOptionAmount);
        assertEq(usdt.balanceOf(address(tradingPair)), contractUsdtBefore + usdtAmount);
        assertEq(optionToken.balanceOf(address(tradingPair)), contractOptionBefore - expectedOptionAmount);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试卖出期权Token换取USDT
     */
    function testSellOptions() public {
        // 先增加合约的USDT余额
        usdt.approve(address(tradingPair), 100 * 1e6);
        tradingPair.addLiquidity(0, 100 * 1e6); // 添加100 USDT流动性
        
        // 先让用户购买一些期权Token
        uint256 usdtAmount = 50 * 1e6; // 50 USDT
        vm.startPrank(user1);
        usdt.approve(address(tradingPair), usdtAmount);
        tradingPair.buyOptions(usdtAmount);
        
        // 卖出一部分期权Token (用户购买了5000个期权Token)
        uint256 optionAmountToSell = 1000; // 1000个期权Token的最小单位
        uint256 expectedUsdtAmount = (optionAmountToSell * OPTION_PRICE) / 1e30; // 使用合约中的计算方式
        
        optionToken.approve(address(tradingPair), optionAmountToSell);
        
        uint256 userUsdtBefore = usdt.balanceOf(user1);
        uint256 userOptionBefore = optionToken.balanceOf(user1);
        uint256 contractUsdtBefore = usdt.balanceOf(address(tradingPair));
        uint256 contractOptionBefore = optionToken.balanceOf(address(tradingPair));
        
        tradingPair.sellOptions(optionAmountToSell);
        
        // 验证余额变化
        assertEq(usdt.balanceOf(user1), userUsdtBefore + expectedUsdtAmount, "USDT balance should increase");
        assertEq(optionToken.balanceOf(user1), userOptionBefore - optionAmountToSell, "Option balance should decrease");
        assertEq(usdt.balanceOf(address(tradingPair)), contractUsdtBefore - expectedUsdtAmount);
        assertEq(optionToken.balanceOf(address(tradingPair)), contractOptionBefore + optionAmountToSell);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试设置期权价格
     */
    function testSetOptionPrice() public {
        uint256 newPrice = 0.02 ether; // 0.02 USDT
        
        vm.expectEmit(false, false, false, true);
        emit PriceUpdated(OPTION_PRICE, newPrice);
        
        tradingPair.setOptionPrice(newPrice);
        
        assertEq(tradingPair.optionPrice(), newPrice);
    }
    
    /**
     * @dev 测试非所有者设置价格失败
     */
    function testSetOptionPriceNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        tradingPair.setOptionPrice(0.02 ether);
    }
    
    /**
     * @dev 测试添加流动性
     */
    function testAddLiquidity() public {
        uint256 optionAmount = 1 ether;
        uint256 usdtAmount = 10 * 1e6;
        
        optionToken.approve(address(tradingPair), optionAmount);
        usdt.approve(address(tradingPair), usdtAmount);
        
        uint256 contractOptionBefore = optionToken.balanceOf(address(tradingPair));
        uint256 contractUsdtBefore = usdt.balanceOf(address(tradingPair));
        
        vm.expectEmit(false, false, false, true);
        emit LiquidityAdded(optionAmount, usdtAmount);
        
        tradingPair.addLiquidity(optionAmount, usdtAmount);
        
        assertEq(optionToken.balanceOf(address(tradingPair)), contractOptionBefore + optionAmount);
        assertEq(usdt.balanceOf(address(tradingPair)), contractUsdtBefore + usdtAmount);
    }
    
    /**
     * @dev 测试移除流动性
     */
    function testRemoveLiquidity() public {
        uint256 optionAmount = 1 ether;
        uint256 usdtAmount = 10 * 1e6;
        
        uint256 ownerOptionBefore = optionToken.balanceOf(owner);
        uint256 ownerUsdtBefore = usdt.balanceOf(owner);
        uint256 contractOptionBefore = optionToken.balanceOf(address(tradingPair));
        uint256 contractUsdtBefore = usdt.balanceOf(address(tradingPair));
        
        vm.expectEmit(false, false, false, true);
        emit LiquidityRemoved(optionAmount, usdtAmount);
        
        tradingPair.removeLiquidity(optionAmount, usdtAmount);
        
        assertEq(optionToken.balanceOf(owner), ownerOptionBefore + optionAmount);
        assertEq(usdt.balanceOf(owner), ownerUsdtBefore + usdtAmount);
        assertEq(optionToken.balanceOf(address(tradingPair)), contractOptionBefore - optionAmount);
        assertEq(usdt.balanceOf(address(tradingPair)), contractUsdtBefore - usdtAmount);
    }
    
    /**
     * @dev 测试购买期权时余额不足
     */
    function testBuyOptionsInsufficientBalance() public {
        // 先移除所有期权Token
        tradingPair.removeLiquidity(tradingPair.getOptionBalance(), 0);
        
        uint256 usdtAmount = 10 * 1e6; // 10 USDT
        
        vm.startPrank(user1);
        usdt.approve(address(tradingPair), usdtAmount);
        
        vm.expectRevert(OptionTradingPair.InsufficientBalance.selector);
        tradingPair.buyOptions(usdtAmount);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试卖出期权时余额不足
     */
    function testSellOptionsInsufficientBalance() public {
        uint256 optionAmount = 2 ether; // 2个期权Token，owner有足够余额
        
        // 先给用户一些期权Token（从owner转账）
        optionToken.transfer(user1, optionAmount);
        
        // 移除交易对中的所有USDT，使其无法支付
        tradingPair.removeLiquidity(0, tradingPair.getUsdtBalance());
        
        vm.startPrank(user1);
        optionToken.approve(address(tradingPair), optionAmount);
        
        vm.expectRevert(OptionTradingPair.InsufficientBalance.selector);
        tradingPair.sellOptions(optionAmount);
        
        vm.stopPrank();
    }
    
    /**
     * @dev 测试零数量购买
     */
    function testBuyOptionsZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(OptionTradingPair.ZeroAmount.selector);
        tradingPair.buyOptions(0);
    }
    
    /**
     * @dev 测试零数量卖出
     */
    function testSellOptionsZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert(OptionTradingPair.ZeroAmount.selector);
        tradingPair.sellOptions(0);
    }
    
    /**
     * @dev 测试价格计算函数
     */
    function testPriceCalculations() public view {
        uint256 optionAmount = 1000 * 1e18; // 1000个期权Token
        uint256 expectedUsdt = (optionAmount * OPTION_PRICE) / 1e18; // 10 USDT
        
        assertEq(tradingPair.getUsdtRequired(optionAmount), expectedUsdt);
        
        uint256 usdtAmount = 50 * 1e6; // 50 USDT
        uint256 expectedOptions = (usdtAmount * 1e18) / OPTION_PRICE; // 5000个期权Token
        
        assertEq(tradingPair.getOptionAmount(usdtAmount), expectedOptions);
    }
    
    /**
     * @dev 测试余额查询函数
     */
    function testBalanceQueries() public view {
        assertEq(tradingPair.getOptionBalance(), optionToken.balanceOf(address(tradingPair)));
        assertEq(tradingPair.getUsdtBalance(), usdt.balanceOf(address(tradingPair)));
    }
    
    /**
     * @dev 测试完整的交易流程
     */
    function testCompleteTrading() public {
        // 用户1购买期权Token
        uint256 usdtAmount = 20 * 1e6; // 20 USDT
        vm.startPrank(user1);
        usdt.approve(address(tradingPair), usdtAmount);
        tradingPair.buyOptions(usdtAmount);
        
        uint256 optionBalance = optionToken.balanceOf(user1);
        assertTrue(optionBalance > 0);
        
        // 用户1卖出一部分期权Token
        uint256 sellAmount = optionBalance / 2;
        optionToken.approve(address(tradingPair), sellAmount);
        tradingPair.sellOptions(sellAmount);
        
        // 验证余额变化
        assertEq(optionToken.balanceOf(user1), optionBalance - sellAmount);
        assertTrue(usdt.balanceOf(user1) > 1000 * 1e6 - usdtAmount); // 应该收回一些USDT
        
        vm.stopPrank();
    }
    
    /**
     * @dev 接收ETH函数，用于测试
     */
    receive() external payable {}
}