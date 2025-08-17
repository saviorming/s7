pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LeverageDEX
 * @dev 基于vAMM（虚拟自动做市商）的杠杆交易合约
 * 核心机制：通过恒定乘积公式 vK = vETHAmount * vUSDCAmount 模拟市场价格
 * 支持多空杠杆交易、平仓和清算功能
 */
contract LeverageDEX {
    // 使用SafeERC20库确保ERC20转账的安全性
    using SafeERC20 for IERC20;

    // vAMM核心参数
    uint public immutable vK;          // 恒定乘积（vETH * vUSDC），部署后不可更改
    uint public vETHAmount;            // 虚拟池中的ETH数量
    uint public vUSDCAmount;           // 虚拟池中的USDC数量

    IERC20 public USDC;                // 真实USDC代币合约地址

    /**
     * @dev 用户头寸结构体
     * margin: 保证金（用户存入的真实USDC）
     * borrowed: 借入的资金（杠杆部分的USDC）
     * position: 虚拟ETH持仓量（正数=多单，负数=空单）
     */
    struct Position {
        uint256 margin;
        uint256 borrowed;
        int256 position;
    }
    
    // 存储用户头寸：地址 => 头寸信息
    mapping(address => Position) public positions;

    /**
     * @dev 构造函数：初始化虚拟池和恒定乘积
     * @param _usdc 真实USDC代币地址
     * @param vEth 初始虚拟ETH数量
     * @param vUSDC 初始虚拟USDC数量
     */
    constructor(IERC20 _usdc, uint vEth, uint vUSDC) {
        USDC = _usdc;
        vETHAmount = vEth;
        vUSDCAmount = vUSDC;
        vK = vEth * vUSDC;  // 计算初始恒定乘积，永久不变
    }

    /**
     * @dev 开启杠杆头寸（做多或做空）
     * @param _margin 保证金数量（真实USDC）
     * @param level 杠杆倍数（至少为1）
     * @param long 交易方向：true=做多ETH，false=做空ETH
     */
    function openPosition(uint256 _margin, uint level, bool long) external {
        // 校验：用户当前没有未平仓头寸
        require(positions[msg.sender].position == 0, "Position already open");
        // 校验：杠杆倍数至少为1（1倍杠杆即无杠杆）
        require(level >= 1, "Leverage level must be at least 1");
        // 校验：保证金不能为0
        require(_margin > 0, "Margin cannot be zero");

        // 获取用户头寸存储引用
        Position storage pos = positions[msg.sender];
        // 从用户钱包转移保证金到合约
        USDC.safeTransferFrom(msg.sender, address(this), _margin);
        
        // 计算总资金量（保证金 + 借入资金）
        uint totalAmount = _margin * level;
        // 计算借入资金量（总资金 - 保证金）
        uint256 borrowAmount = totalAmount - _margin;

        // 记录用户头寸的基础信息
        pos.margin = _margin;
        pos.borrowed = borrowAmount;

        if (long) {
            // ==================== 做多逻辑 ====================
            // 1. 计算需要注入虚拟池的USDC数量（等于总资金）
            uint deltaVusdc = totalAmount;
            // 2. 计算注入后虚拟池的USDC余额
            uint newVusdc = vUSDCAmount + deltaVusdc;
            // 3. 根据恒定乘积计算新的虚拟ETH余额（vK / 新USDC余额）
            uint newVeth = vK / newVusdc;
            // 4. 计算用户获得的虚拟ETH数量（原ETH余额 - 新ETH余额）
            uint deltaVeth = vETHAmount - newVeth;
            // 5. 记录多头头寸（正数表示持有ETH）
            pos.position = int256(deltaVeth);
            
            // 6. 更新虚拟池余额
            vETHAmount = newVeth;
            vUSDCAmount = newVusdc;
        } else {
            // ==================== 做空逻辑 ====================
            // 1. 计算需要从虚拟池取出的USDC数量（等于总资金）
            uint deltaVusdc = totalAmount;
            // 校验：虚拟池有足够的USDC可供取出
            require(vUSDCAmount >= deltaVusdc, "Insufficient vUSDC in pool");
            
            // 2. 计算取出后虚拟池的USDC余额
            uint newVusdc = vUSDCAmount - deltaVusdc;
            // 3. 根据恒定乘积计算新的虚拟ETH余额（vK / 新USDC余额）
            uint newVeth = vK / newVusdc;
            // 4. 计算用户需要注入的虚拟ETH数量（新ETH余额 - 原ETH余额）
            uint deltaVeth = newVeth - vETHAmount;
            
            // 校验：确保ETH数量为正数（注入有效）
            require(deltaVeth > 0, "Invalid short position");
            // 5. 记录空头头寸（负数表示借入ETH）
            pos.position = -int256(deltaVeth);
            
            // 6. 更新虚拟池余额
            vETHAmount = newVeth;
            vUSDCAmount = newVusdc;
        }
    }

    /**
     * @dev 关闭当前头寸，结算利润或亏损
     */
    function closePosition() external {
        // 获取用户头寸
        Position storage pos = positions[msg.sender];
        // 校验：用户有未平仓头寸
        require(pos.position != 0, "No open position");

        // 保存当前头寸信息（后续将清空存储）
        int256 position = pos.position;
        uint margin = pos.margin;
        uint borrowed = pos.borrowed;
        // 清空头寸记录
        delete positions[msg.sender];

        if (position > 0) {
            // ==================== 平多单 ====================
            // 1. 转换多头头寸为需要归还的ETH数量
            uint deltaVeth = uint256(position);
            // 2. 计算归还后虚拟池的ETH余额
            uint newVeth = vETHAmount + deltaVeth;
            // 3. 根据恒定乘积计算新的USDC余额
            uint newVusdc = vK / newVeth;
            // 4. 计算平仓获得的USDC（原USDC余额 - 新USDC余额）
            uint deltaVusdc = vUSDCAmount - newVusdc;
            
            // 5. 更新虚拟池余额
            vETHAmount = newVeth;
            vUSDCAmount = newVusdc;
            
            // 6. 计算利润（获得的USDC - 借入资金）
            uint proceeds = deltaVusdc > borrowed ? deltaVusdc - borrowed : 0;
            // 7. 计算总返还金额（保证金 + 利润）
            uint totalReturn = margin + proceeds;
            // 8. 返还资金给用户（如有）
            if (totalReturn > 0) {
                USDC.safeTransfer(msg.sender, totalReturn);
            }
        } else {
            // ==================== 平空单 ====================
            // 1. 转换空头头寸为需要归还的ETH数量（取绝对值）
            uint deltaVeth = uint256(-position);
            // 2. 计算归还后虚拟池的ETH余额
            uint newVeth = vETHAmount - deltaVeth;
            // 3. 根据恒定乘积计算新的USDC余额
            uint newVusdc = vK / newVeth;
            // 4. 计算平仓获得的USDC（新USDC余额 - 原USDC余额）
            uint deltaVusdc = newVusdc - vUSDCAmount;
            
            // 5. 更新虚拟池余额
            vETHAmount = newVeth;
            vUSDCAmount = newVusdc;
            
            // 6. 计算利润（获得的USDC - 借入资金）
            uint proceeds = deltaVusdc > borrowed ? deltaVusdc - borrowed : 0;
            // 7. 计算总返还金额（保证金 + 利润）
            uint totalReturn = margin + proceeds;
            // 8. 返还资金给用户（如有）
            if (totalReturn > 0) {
                USDC.safeTransfer(msg.sender, totalReturn);
            }
        }
    }

    /**
     * @dev 清算亏损严重的用户头寸
     * @param _user 被清算的用户地址
     */
    function liquidatePosition(address _user) external {
        // 校验：不能清算自己
        require(_user != msg.sender, "Cannot liquidate yourself");
        
        // 获取被清算用户的头寸
        Position memory pos = positions[_user];
        // 校验：该用户有未平仓头寸
        require(pos.position != 0, "No open position");
        
        // 计算当前头寸的盈亏
        int256 pnl = calculatePnL(_user);
        // 校验：亏损超过保证金的80%（满足清算条件）
        require(pnl <= -int256(pos.margin * 80 / 100), "Position not eligible");

        // 保存头寸信息并清空头寸
        int256 position = pos.position;
        uint borrowed = pos.borrowed;
        delete positions[_user];

        if (position > 0) {
            // ==================== 清算多单 ====================
            uint deltaVeth = uint256(position);
            uint newVeth = vETHAmount + deltaVeth;
            uint newVusdc = vK / newVeth;
            uint deltaVusdc = vUSDCAmount - newVusdc;
            
            // 更新虚拟池余额
            vETHAmount = newVeth;
            vUSDCAmount = newVusdc;
            
            // 清算人获得奖励（扣除借款后的剩余价值）
            uint reward = deltaVusdc > borrowed ? deltaVusdc - borrowed : 0;
            if (reward > 0) {
                USDC.safeTransfer(msg.sender, reward);
            }
        } else {
            // ==================== 清算空单 ====================
            uint deltaVeth = uint256(-position);
            uint newVeth = vETHAmount - deltaVeth;
            uint newVusdc = vK / newVeth;
            uint deltaVusdc = newVusdc - vUSDCAmount;
            
            // 更新虚拟池余额
            vETHAmount = newVeth;
            vUSDCAmount = newVusdc;
            
            // 清算人获得奖励
            uint reward = deltaVusdc > borrowed ? deltaVusdc - borrowed : 0;
            if (reward > 0) {
                USDC.safeTransfer(msg.sender, reward);
            }
        }
    }

    /**
     * @dev 计算用户当前头寸的盈亏
     * @param user 用户地址
     * @return 盈亏金额（正数=盈利，负数=亏损）
     */
    function calculatePnL(address user) public view returns (int256) {
        Position memory pos = positions[user];
        // 校验：用户有未平仓头寸
        require(pos.position != 0, "No open position");

        if (pos.position > 0) {
            // 多单盈亏计算
            uint deltaVeth = uint256(pos.position);
            uint newVeth = vETHAmount + deltaVeth;
            uint newVusdc = vK / newVeth;
            uint deltaVusdc = vUSDCAmount - newVusdc;
            
            // 盈亏 =（获得的USDC - 借入资金）- 保证金
            return int256(deltaVusdc - pos.borrowed) - int256(pos.margin);
        } else {
            // 空单盈亏计算
            uint deltaVeth = uint256(-pos.position);
            uint newVeth = vETHAmount - deltaVeth;
            uint newVusdc = vK / newVeth;
            uint deltaVusdc = newVusdc - vUSDCAmount;
            
            // 盈亏 =（获得的USDC - 借入资金）- 保证金
            return int256(deltaVusdc - pos.borrowed) - int256(pos.margin);
        }
    }

    /**
     * @dev 获取当前虚拟池中的ETH价格（USDC/ETH）
     * @return 当前ETH价格（USDC单位）
     */
    function getEthPrice() public view returns (uint) {
        // 价格 = 虚拟USDC余额 / 虚拟ETH余额
        return vUSDCAmount / vETHAmount;
    }
}
