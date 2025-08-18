// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Defi/options/CallOptionToken.sol";
import "../src/Defi/options/MockUSDT.sol";

/**
 * @title CallOptionTokenTest
 * @dev 看涨期权Token的完整测试套件
 */
contract CallOptionTokenTest is Test {
    CallOptionToken public optionToken;
    MockUSDT public usdt;
    
    address public owner;
    address public user1;
    address public user2;
    address public user3;
    
    // 期权参数
    uint256 public constant STRIKE_PRICE = 0.1 ether;      // 行权价格: 0.1 ETH
    uint256 public constant UNDERLYING_PRICE = 0.08 ether; // 创建时ETH价格: 0.08 ETH
    uint256 public expirationTime;
    
    // 测试常量
    uint256 public constant INITIAL_ETH_DEPOSIT = 10 ether;
    uint256 public constant INITIAL_USDT_SUPPLY = 1000000; // 100万 USDT
    
    event OptionsIssued(address indexed issuer, uint256 ethAmount, uint256 optionTokens);
    event OptionsExercised(address indexed exerciser, uint256 optionTokens, uint256 ethReceived);
    event ExpiredOptionsDestroyed(uint256 optionTokensDestroyed, uint256 ethRedeemed);
    
    function setUp() public {
        // 设置测试账户
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        // 给测试账户分配ETH
        vm.deal(owner, 100 ether);
        vm.deal(user1, 50 ether);
        vm.deal(user2, 50 ether);
        vm.deal(user3, 50 ether);
        
        // 设置到期时间为7天后
        expirationTime = block.timestamp + 7 days;
        
        // 部署USDT模拟合约
        usdt = new MockUSDT(INITIAL_USDT_SUPPLY);
        
        // 部署合约
        optionToken = new CallOptionToken(
            "ETH Call Option 2000",
            "ETH-CALL-2000",
            STRIKE_PRICE,
            expirationTime,
            UNDERLYING_PRICE,
            address(usdt)
        );
        
        // 给用户分配USDT (需要足够的USDT来支付行权费用)
        usdt.mint(user1, 1000000 * 1e6); // 100万 USDT
        usdt.mint(user2, 1000000 * 1e6); // 100万 USDT
        usdt.mint(user3, 1000000 * 1e6); // 100万 USDT
    }
    
    /**
     * @dev 测试合约初始化
     */
    function testInitialization() public {
        assertEq(optionToken.name(), "ETH Call Option 2000");
        assertEq(optionToken.symbol(), "ETH-CALL-2000");
        assertEq(optionToken.strikePrice(), STRIKE_PRICE);
        assertEq(optionToken.expirationTime(), expirationTime);
        assertEq(optionToken.underlyingPrice(), UNDERLYING_PRICE);
        assertEq(optionToken.totalSupply(), 0);
        assertEq(optionToken.totalEthDeposited(), 0);
        assertEq(optionToken.totalOptionsIssued(), 0);
        assertFalse(optionToken.isExpired());
        assertFalse(optionToken.canExercise());
    }
    
    /**
     * @dev 测试无效参数的构造函数
     */
    function testInvalidConstructorParameters() public {
        // 测试零行权价格
        vm.expectRevert(CallOptionToken.InvalidParameters.selector);
        new CallOptionToken(
            "Invalid Option",
            "INVALID",
            0, // 无效的行权价格
            block.timestamp + 1 days,
            1800 ether,
            address(usdt)
        );
        
        // 测试过期时间在过去
        vm.expectRevert(CallOptionToken.InvalidParameters.selector);
        new CallOptionToken(
            "Invalid Option",
            "INVALID",
            2000 ether,
            block.timestamp - 1, // 过期时间在过去
            1800 ether,
            address(usdt)
        );
        
        // 测试零标的价格
        vm.expectRevert(CallOptionToken.InvalidParameters.selector);
        new CallOptionToken(
            "Invalid Option",
            "INVALID",
            2000 ether,
            block.timestamp + 1 days,
            0, // 无效的标的价格
            address(usdt)
        );
        
        // 测试零USDT地址
        vm.expectRevert(CallOptionToken.InvalidParameters.selector);
        new CallOptionToken(
            "Invalid Option",
            "INVALID",
            2000 ether,
            block.timestamp + 1 days,
            1800 ether,
            address(0) // 无效的USDT地址
        );
    }
    
    /**
     * @dev 测试期权发行功能
     */
    function testIssueOptions() public {
        // 测试成功发行
        vm.expectEmit(true, false, false, true);
        emit OptionsIssued(owner, INITIAL_ETH_DEPOSIT, INITIAL_ETH_DEPOSIT);
        
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        // 验证状态
        assertEq(optionToken.totalEthDeposited(), INITIAL_ETH_DEPOSIT);
        assertEq(optionToken.totalOptionsIssued(), INITIAL_ETH_DEPOSIT);
        assertEq(optionToken.balanceOf(owner), INITIAL_ETH_DEPOSIT);
        assertEq(optionToken.totalSupply(), INITIAL_ETH_DEPOSIT);
        assertEq(address(optionToken).balance, INITIAL_ETH_DEPOSIT);
    }
    
    /**
     * @dev 测试非所有者发行期权
     */
    function testIssueOptionsNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        optionToken.issueOptions{value: 1 ether}();
    }
    
    /**
     * @dev 测试零ETH发行期权
     */
    function testIssueOptionsZeroEth() public {
        vm.expectRevert(CallOptionToken.InsufficientEthDeposit.selector);
        optionToken.issueOptions{value: 0}();
    }
    
    /**
     * @dev 测试过期后发行期权
     */
    function testIssueOptionsAfterExpiration() public {
        // 跳转到过期时间
        vm.warp(expirationTime + 1);
        
        vm.expectRevert(CallOptionToken.OptionExpired.selector);
        optionToken.issueOptions{value: 1 ether}();
    }
    
    /**
     * @dev 测试期权转账功能
     */
    function testOptionTransfer() public {
        // 先发行期权
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        // 转账给用户1
        uint256 transferAmount = 2 ether;
        optionToken.transfer(user1, transferAmount);
        
        // 验证余额
        assertEq(optionToken.balanceOf(user1), transferAmount);
        assertEq(optionToken.balanceOf(owner), INITIAL_ETH_DEPOSIT - transferAmount);
    }
    
    /**
     * @dev 测试期权授权和转账
     */
    function testOptionApproveAndTransferFrom() public {
        // 先发行期权
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        // 授权给用户1
        uint256 approveAmount = 3 ether;
        optionToken.approve(user1, approveAmount);
        
        // 用户1代表owner转账给用户2
        uint256 transferAmount = 2 ether;
        vm.prank(user1);
        optionToken.transferFrom(owner, user2, transferAmount);
        
        // 验证余额和授权
        assertEq(optionToken.balanceOf(user2), transferAmount);
        assertEq(optionToken.balanceOf(owner), INITIAL_ETH_DEPOSIT - transferAmount);
        assertEq(optionToken.allowance(owner, user1), approveAmount - transferAmount);
    }
    
    /**
     * @dev 测试期权行权功能
     */
    function testExerciseOptions() public {
        // 先发行期权并转账给用户
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        uint256 optionAmount = 2 ether;
        optionToken.transfer(user1, optionAmount);
        
        // 跳转到可行权时间
        vm.warp(expirationTime);
        
        // 计算需要支付的USDT (行权价格是USDT，6位小数)
        uint256 usdtRequired = (optionAmount * STRIKE_PRICE) / 1e18;
        
        // 用户1授权USDT给期权合约
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtRequired);
        
        // 用户1行权
        uint256 user1BalanceBefore = user1.balance;
        uint256 user1UsdtBefore = usdt.balanceOf(user1);
        
        vm.expectEmit(true, false, false, true);
        emit OptionsExercised(user1, optionAmount, optionAmount);
        
        vm.prank(user1);
        optionToken.exerciseOptions(optionAmount);
        
        // 验证状态
        assertEq(optionToken.balanceOf(user1), 0); // 期权Token被销毁
        assertEq(user1.balance, user1BalanceBefore + optionAmount); // 获得ETH
        assertEq(usdt.balanceOf(user1), user1UsdtBefore - usdtRequired); // 支付了USDT
        assertEq(optionToken.totalSupply(), INITIAL_ETH_DEPOSIT - optionAmount); // 总供应量减少
    }
    
    /**
     * @dev 测试提前行权失败
     */
    function testExerciseOptionsBeforeExpiration() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        optionToken.transfer(user1, 1 ether);
        
        vm.prank(user1);
        vm.expectRevert(CallOptionToken.ExerciseNotAllowed.selector);
        optionToken.exerciseOptions(1 ether);
    }
    
    /**
     * @dev 测试行权期过后行权失败
     */
    function testExerciseOptionsAfterExercisePeriod() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        optionToken.transfer(user1, 1 ether);
        
        // 跳转到行权期结束后
        vm.warp(expirationTime + 2 days);
        
        vm.prank(user1);
        vm.expectRevert(CallOptionToken.OptionExpired.selector);
        optionToken.exerciseOptions(1 ether);
    }
    
    /**
     * @dev 测试余额不足行权失败
     */
    function testExerciseOptionsInsufficientBalance() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        vm.warp(expirationTime);
        
        vm.prank(user1); // user1没有期权Token
        vm.expectRevert(CallOptionToken.InsufficientOptionTokens.selector);
        optionToken.exerciseOptions(1 ether);
    }
    
    /**
     * @dev 测试USDT授权不足行权失败
     */
    function testExerciseOptionsInsufficientPayment() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        optionToken.transfer(user1, 1 ether);
        
        vm.warp(expirationTime);
        
        // 计算需要的USDT但不授权足够的数量
        uint256 usdtRequired = (1 ether * STRIKE_PRICE) / 1e18;
        
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtRequired - 1); // 授权不足
        
        vm.prank(user1);
        vm.expectRevert(CallOptionToken.InsufficientUsdtAllowance.selector);
        optionToken.exerciseOptions(1 ether);
    }
    
    /**
     * @dev 测试过期销毁功能
     */
    function testDestroyExpiredOptions() public {
        // 发行期权
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        // 转账部分期权给用户（模拟部分期权未行权）
        optionToken.transfer(user1, 3 ether);
        
        // 跳转到销毁时间
        vm.warp(expirationTime + 2 days);
        
        uint256 ownerBalanceBefore = owner.balance;
        uint256 remainingTokens = optionToken.totalSupply();
        uint256 contractBalance = address(optionToken).balance;
        
        vm.expectEmit(false, false, false, true);
        emit ExpiredOptionsDestroyed(remainingTokens, contractBalance);
        
        optionToken.destroyExpiredOptions();
        
        // 验证状态
        assertTrue(optionToken.isExpired());
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);
        assertEq(address(optionToken).balance, 0);
    }
    
    /**
     * @dev 测试提前销毁失败
     */
    function testDestroyExpiredOptionsBeforeExpiration() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        vm.expectRevert(CallOptionToken.OptionNotExpired.selector);
        optionToken.destroyExpiredOptions();
    }
    
    /**
     * @dev 测试非所有者销毁失败
     */
    function testDestroyExpiredOptionsNotOwner() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        vm.warp(expirationTime + 2 days);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        optionToken.destroyExpiredOptions();
    }
    
    /**
     * @dev 测试内在价值计算
     */
    function testIntrinsicValue() public {
        // 当前价格高于行权价格
        uint256 currentPrice = 0.15 ether;
        uint256 intrinsic = optionToken.intrinsicValue(currentPrice);
        assertEq(intrinsic, currentPrice - STRIKE_PRICE);
        
        // 当前价格低于行权价格
        currentPrice = 0.05 ether;
        intrinsic = optionToken.intrinsicValue(currentPrice);
        assertEq(intrinsic, 0);
        
        // 当前价格等于行权价格
        currentPrice = STRIKE_PRICE;
        intrinsic = optionToken.intrinsicValue(currentPrice);
        assertEq(intrinsic, 0);
    }
    
    /**
     * @dev 测试canExercise函数
     */
    function testCanExercise() public {
        // 发行前不能行权
        assertFalse(optionToken.canExercise());
        
        // 发行后到期前不能行权
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        assertFalse(optionToken.canExercise());
        
        // 到期时可以行权
        vm.warp(expirationTime);
        assertTrue(optionToken.canExercise());
        
        // 行权期内可以行权
        vm.warp(expirationTime + 12 hours);
        assertTrue(optionToken.canExercise());
        
        // 行权期结束后不能行权
        vm.warp(expirationTime + 2 days);
        assertFalse(optionToken.canExercise());
    }
    
    /**
     * @dev 测试获取期权详细信息
     */
    function testGetOptionDetails() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        (
            uint256 _strikePrice,
            uint256 _expirationTime,
            uint256 _underlyingPrice,
            uint256 _totalEthDeposited,
            uint256 _totalOptionsIssued,
            bool _isExpired,
            bool _canExercise
        ) = optionToken.getOptionDetails();
        
        assertEq(_strikePrice, STRIKE_PRICE);
        assertEq(_expirationTime, expirationTime);
        assertEq(_underlyingPrice, UNDERLYING_PRICE);
        assertEq(_totalEthDeposited, INITIAL_ETH_DEPOSIT);
        assertEq(_totalOptionsIssued, INITIAL_ETH_DEPOSIT);
        assertFalse(_isExpired);
        assertFalse(_canExercise);
    }
    
    /**
     * @dev 测试紧急提取功能
     */
    function testEmergencyWithdraw() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        uint256 ownerBalanceBefore = owner.balance;
        uint256 contractBalance = address(optionToken).balance;
        
        optionToken.emergencyWithdraw();
        
        assertEq(owner.balance, ownerBalanceBefore + contractBalance);
        assertEq(address(optionToken).balance, 0);
    }
    
    /**
     * @dev 测试非所有者紧急提取失败
     */
    function testEmergencyWithdrawNotOwner() public {
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        optionToken.emergencyWithdraw();
    }
    
    /**
     * @dev 测试合约接收ETH
     */
    function testReceiveEth() public {
        uint256 sendAmount = 1 ether;
        
        (bool success,) = address(optionToken).call{value: sendAmount}("");
        assertTrue(success);
        assertEq(address(optionToken).balance, sendAmount);
    }
    
    /**
     * @dev 接收ETH函数，用于测试
     */
    receive() external payable {}
    
    /**
     * @dev 测试完整的期权生命周期
     */
    function testCompleteOptionLifecycle() public {
        // 1. 发行期权
        optionToken.issueOptions{value: INITIAL_ETH_DEPOSIT}();
        
        // 2. 转账期权给用户
        uint256 optionAmount = 3 ether;
        optionToken.transfer(user1, optionAmount);
        optionToken.transfer(user2, optionAmount);
        
        // 3. 到期时用户1行权
        vm.warp(expirationTime);
        
        uint256 usdtRequired = (optionAmount * STRIKE_PRICE) / 1e18;
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtRequired);
        
        vm.prank(user1);
        optionToken.exerciseOptions(optionAmount);
        
        // 4. 过期后销毁剩余期权
        vm.warp(expirationTime + 2 days);
        optionToken.destroyExpiredOptions();
        
        // 验证最终状态
        assertTrue(optionToken.isExpired());
        assertEq(optionToken.balanceOf(user1), 0); // 已行权
        assertEq(address(optionToken).balance, 0); // 合约余额为0
    }
    
    /**
      * @dev 测试完整的发行和行权过程（带详细日志）
      */
     function testDetailedIssuanceAndExerciseProcess() public {
         console.log(unicode"=== 开始期权发行和行权演示 ===");
         
         // 记录初始状态
         console.log(unicode"初始状态:");
         console.log(unicode"- 合约ETH余额:", address(optionToken).balance);
         console.log(unicode"- 期权总供应量:", optionToken.totalSupply());
         console.log(unicode"- 行权价格(USDT):", STRIKE_PRICE / 1e12); // 转换为USDT单位显示
         console.log(unicode"- 到期时间:", expirationTime);
         console.log(unicode"- 当前时间:", block.timestamp);
         
         // 1. 发行期权
         console.log(unicode"\n=== 步骤1: 发行期权 ===");
         uint256 issueAmount = 5 ether;
         console.log(unicode"发行ETH数量:", issueAmount);
         
         optionToken.issueOptions{value: issueAmount}();
         
         console.log(unicode"发行后状态:");
         console.log(unicode"- 合约ETH余额:", address(optionToken).balance);
         console.log(unicode"- 期权总供应量:", optionToken.totalSupply());
         console.log(unicode"- 所有者期权余额:", optionToken.balanceOf(owner));
         console.log(unicode"- 总ETH存款:", optionToken.totalEthDeposited());
         console.log(unicode"- 总期权发行量:", optionToken.totalOptionsIssued());
         
         // 2. 分发期权给用户
         console.log(unicode"\n=== 步骤2: 分发期权给用户 ===");
         uint256 user1Amount = 2 ether;
         uint256 user2Amount = 1.5 ether;
         
         optionToken.transfer(user1, user1Amount);
         optionToken.transfer(user2, user2Amount);
         
         console.log(unicode"分发后余额:");
         console.log(unicode"- 用户1期权余额:", optionToken.balanceOf(user1));
         console.log(unicode"- 用户2期权余额:", optionToken.balanceOf(user2));
         console.log(unicode"- 所有者剩余期权:", optionToken.balanceOf(owner));
         
         // 3. 等待到期
         console.log(unicode"\n=== 步骤3: 等待到期 ===");
         console.log(unicode"当前可以行权吗?", optionToken.canExercise());
         
         vm.warp(expirationTime);
         console.log(unicode"跳转到到期时间:", block.timestamp);
         console.log(unicode"现在可以行权吗?", optionToken.canExercise());
        
        // 4. 用户1行权
        console.log(unicode"\n=== 步骤4: 用户1行权 ===");
        uint256 exerciseAmount = user1Amount;
        uint256 usdtRequired = (exerciseAmount * STRIKE_PRICE) / 1e18;
        
        console.log(unicode"行权详情:");
        console.log(unicode"- 行权期权数量:", exerciseAmount);
        console.log(unicode"- 需要支付USDT:", usdtRequired / 1e6); // 转换为USDT单位显示
        console.log(unicode"- 用户1行权前ETH余额:", user1.balance);
        console.log(unicode"- 用户1行权前USDT余额:", usdt.balanceOf(user1) / 1e6);
        
        // 授权USDT
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtRequired);
        console.log(unicode"- USDT授权完成");
        
        // 执行行权
        vm.prank(user1);
        optionToken.exerciseOptions(exerciseAmount);
        
        console.log(unicode"行权后状态:");
        console.log(unicode"- 用户1期权余额:", optionToken.balanceOf(user1));
        console.log(unicode"- 用户1ETH余额:", user1.balance);
        console.log(unicode"- 用户1USDT余额:", usdt.balanceOf(user1) / 1e6);
        console.log(unicode"- 合约ETH余额:", address(optionToken).balance);
        console.log(unicode"- 期权总供应量:", optionToken.totalSupply());
        console.log(unicode"- 合约USDT余额:", usdt.balanceOf(address(optionToken)) / 1e6);
        
        // 5. 检查内在价值
        console.log(unicode"\n=== 步骤5: 检查内在价值 ===");
        uint256 currentPrice = 0.12 ether; // 假设当前ETH价格
        uint256 intrinsic = optionToken.intrinsicValue(currentPrice);
        console.log(unicode"当前ETH价格:", currentPrice / 1e12); // 转换显示
        console.log(unicode"期权内在价值:", intrinsic / 1e12);
        
        // 6. 等待行权期结束并销毁剩余期权
        console.log(unicode"\n=== 步骤6: 销毁过期期权 ===");
        vm.warp(expirationTime + 2 days);
        console.log(unicode"跳转到销毁时间:", block.timestamp);
        console.log(unicode"现在可以行权吗?", optionToken.canExercise());
        console.log(unicode"期权已过期吗?", optionToken.isExpired());
        
        uint256 ownerBalanceBefore = owner.balance;
        uint256 remainingTokens = optionToken.totalSupply();
        uint256 contractEthBalance = address(optionToken).balance;
        
        console.log(unicode"销毁前状态:");
        console.log(unicode"- 剩余期权数量:", remainingTokens);
        console.log(unicode"- 合约ETH余额:", contractEthBalance);
        console.log(unicode"- 所有者ETH余额:", ownerBalanceBefore);
        
        optionToken.destroyExpiredOptions();
        
        console.log(unicode"销毁后状态:");
        console.log(unicode"- 所有者ETH余额:", owner.balance);
        console.log(unicode"- 合约ETH余额:", address(optionToken).balance);
        console.log(unicode"- 期权已过期:", optionToken.isExpired());
        
        // 7. 最终验证
        console.log(unicode"\n=== 最终验证 ===");
        assertTrue(optionToken.isExpired());
        assertEq(optionToken.balanceOf(user1), 0);
        assertEq(address(optionToken).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + contractEthBalance);
        
        console.log(unicode"=== 期权生命周期演示完成 ===");
    }
    
    /**
     * @dev 测试多次发行期权
     */
    function testMultipleIssuance() public {
        // 第一次发行
        optionToken.issueOptions{value: 5 ether}();
        assertEq(optionToken.totalEthDeposited(), 5 ether);
        assertEq(optionToken.totalOptionsIssued(), 5 ether);
        
        // 第二次发行
        optionToken.issueOptions{value: 3 ether}();
        assertEq(optionToken.totalEthDeposited(), 8 ether);
        assertEq(optionToken.totalOptionsIssued(), 8 ether);
        assertEq(optionToken.balanceOf(owner), 8 ether);
    }
    
    /**
     * @dev Fuzz测试：随机金额发行期权
     */
    function testFuzzIssueOptions(uint256 amount) public {
        // 限制测试范围
        vm.assume(amount > 0 && amount <= 100 ether);
        vm.assume(block.timestamp < expirationTime);
        
        // 确保有足够的ETH
        vm.deal(owner, amount);
        
        optionToken.issueOptions{value: amount}();
        
        assertEq(optionToken.totalEthDeposited(), amount);
        assertEq(optionToken.totalOptionsIssued(), amount);
        assertEq(optionToken.balanceOf(owner), amount);
    }
    
    /**
     * @dev Fuzz测试：随机金额行权
     */
    function testFuzzExerciseOptions(uint256 issueAmount, uint256 exerciseAmount) public {
        // 限制测试范围
        vm.assume(issueAmount > 0 && issueAmount <= 50 ether);
        vm.assume(exerciseAmount > 0 && exerciseAmount <= issueAmount);
        
        // 确保有足够的ETH
        vm.deal(owner, issueAmount);
        
        // 发行期权
        optionToken.issueOptions{value: issueAmount}();
        optionToken.transfer(user1, exerciseAmount);
        
        // 跳转到可行权时间
        vm.warp(expirationTime);
        
        // 计算需要支付的USDT
        uint256 usdtRequired = (exerciseAmount * STRIKE_PRICE) / 1e18;
        
        // 确保用户有足够USDT并授权
        vm.prank(user1);
        usdt.approve(address(optionToken), usdtRequired);
        
        // 行权
        vm.prank(user1);
        optionToken.exerciseOptions(exerciseAmount);
        
        // 验证
        assertEq(optionToken.balanceOf(user1), 0);
        assertEq(optionToken.totalSupply(), issueAmount - exerciseAmount);
    }
}