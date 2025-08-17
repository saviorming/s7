pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 基于vAmm机制的简单杠杆DEX实现
contract SimpleLeverageDEX {

    uint256 public K; // vAmm常数乘积 K = x * y
    uint256 public vETHReserve;  // 虚拟ETH储备
    uint256 public vUSDCReserve; // 虚拟USDC储备
    uint256 public constant LIQUIDATION_THRESHOLD = 10; // 清算阈值10%
    uint256 public constant LIQUIDATION_REWARD = 5; // 清算奖励5%

    IERC20 public immutable USDC;  // USDC代币合约

    struct Position {
        uint256 margin;        // 保证金 (USDC精度，1e6)
        uint256 notional;      // 名义价值 (USDC精度，1e6)
        uint256 leverage;      // 杠杆倍数
        int256 size;           // 仓位大小(正数做多，负数做空) (ETH精度，1e18)
        uint256 entryPrice;    // 开仓价格 (USDC/ETH价格，1e18精度)
        bool isLong;           // 是否做多
    }
    
    mapping(address => Position) public positions;
    
    // 事件
    event PositionOpened(address indexed trader, uint256 margin, uint256 leverage, bool isLong, uint256 entryPrice, int256 size);
    event PositionClosed(address indexed trader, int256 pnl, uint256 returnAmount);
    event PositionLiquidated(address indexed trader, address indexed liquidator, uint256 liquidationReward);

    constructor(address _usdc, uint256 _vETHReserve, uint256 _vUSDCReserve) {
        USDC = IERC20(_usdc);
        vETHReserve = _vETHReserve;
        vUSDCReserve = _vUSDCReserve;
        K = _vETHReserve * _vUSDCReserve; // 初始化K值
    }


    // 获取当前价格 (USDC per ETH, 以1e18精度返回)
    function getCurrentPrice() public view returns (uint256) {
        return (vUSDCReserve * 1e18) / vETHReserve;
    }
    
    // 根据交易量计算新价格
    function getNewPrice(uint256 quoteAmount, bool isLong) public view returns (uint256) {
        if (isLong) {
            // 做多：用USDC买ETH，USDC储备增加，ETH储备减少
            uint256 newVUSDCReserve = vUSDCReserve + quoteAmount;
            uint256 newVETHReserve = K / newVUSDCReserve;
            return (newVUSDCReserve * 1e18) / newVETHReserve;
        } else {
            // 做空：卖ETH得USDC，USDC储备减少，ETH储备增加
            uint256 newVUSDCReserve = vUSDCReserve - quoteAmount;
            uint256 newVETHReserve = K / newVUSDCReserve;
            return (newVUSDCReserve * 1e18) / newVETHReserve;
        }
    }

    // 开启杠杆头寸
    function openPosition(uint256 _margin, uint256 _leverage, bool _isLong) external {
        require(positions[msg.sender].margin == 0, "Position already exists");
        require(_margin > 0, "Margin must be greater than 0");
        require(_leverage >= 1 && _leverage <= 10, "Leverage must be between 1 and 10");
        
        // 转入保证金
        USDC.transferFrom(msg.sender, address(this), _margin);
        
        // 计算名义价值
        uint256 notional = _margin * _leverage;
        
        // 更新虚拟储备
        if (_isLong) {
            // 做多：用USDC买ETH，增加vUSDCReserve，减少vETHReserve
            vUSDCReserve += notional;
            vETHReserve = K / vUSDCReserve;
        } else {
            // 做空：借入ETH并卖出获得USDC，使用恒定乘积公式
            vUSDCReserve -= notional;
            vETHReserve = K / vUSDCReserve;
        }
        
        // 获取开仓价格（更新储备后的价格）
        uint256 entryPrice = getCurrentPrice();
        
        // 计算仓位大小 (以ETH为单位，使用1e18精度)
        int256 size = int256((notional * 1e18) / entryPrice);
        if (!_isLong) {
            size = -size; // 做空为负数
        }
        
        // 保存仓位信息
        positions[msg.sender] = Position({
            margin: _margin,
            notional: notional,
            leverage: _leverage,
            size: size,
            entryPrice: entryPrice,
            isLong: _isLong
        });
        
        emit PositionOpened(msg.sender, _margin, _leverage, _isLong, entryPrice, size);
    }

    // 关闭头寸并结算
    function closePosition() external {
        Position storage pos = positions[msg.sender];
        require(pos.margin > 0, "No open position");
        
        // 计算PnL
        int256 pnl = calculatePnL(msg.sender);
        
        // 计算返还金额 (以USDC精度，即1e6)
        uint256 returnAmount;
        if (pnl >= 0) {
            // pnl现在已经是USDC价值(1e6精度)，可以直接使用
            returnAmount = pos.margin + uint256(pnl);
        } else {
            uint256 loss = uint256(-pnl); // pnl已经是USDC精度
            if (loss >= pos.margin) {
                returnAmount = 0; // 亏损超过保证金
            } else {
                returnAmount = pos.margin - loss;
            }
        }
        
        // 恢复虚拟储备到开仓前状态
        if (pos.isLong) {
            // 做多时开仓增加了vUSDCReserve，平仓时应该减少
            if (vUSDCReserve > pos.notional) {
                vUSDCReserve -= pos.notional;
            } else {
                // 如果储备不足，设置为最小值
                vUSDCReserve = 1e6; // 1 USDC
            }
            // 重新计算vETHReserve
            vETHReserve = K / vUSDCReserve;
        } else {
            // 做空时开仓减少了vUSDCReserve，平仓时应该恢复
            vUSDCReserve += pos.notional;
            vETHReserve = K / vUSDCReserve;
        }
        
        // 清除仓位
        delete positions[msg.sender];
        
        // 转账
        if (returnAmount > 0) {
            USDC.transfer(msg.sender, returnAmount);
        }
        
        emit PositionClosed(msg.sender, pnl, returnAmount);
    }

    // 计算盈亏 (返回值为1e18精度)
    function calculatePnL(address user) public view returns (int256) {
        Position storage pos = positions[user];
        if (pos.margin == 0) return 0;
        
        uint256 currentPrice = getCurrentPrice();
        uint256 entryPrice = pos.entryPrice;
        
        // 计算价格变化比例 (1e18精度)
        int256 priceChangeRatio;
        if (currentPrice > entryPrice) {
            priceChangeRatio = int256((currentPrice - entryPrice) * 1e18 / entryPrice);
        } else {
            priceChangeRatio = -int256((entryPrice - currentPrice) * 1e18 / entryPrice);
        }
        
        // 计算PnL = 仓位大小 * 价格变化比例 / 1e18
        // pos.size已经是ETH精度(1e18)，priceChangeRatio也是1e18精度
        // 结果是ETH数量(1e18精度)
        int256 pnlInETH = (pos.size * priceChangeRatio) / 1e18;
        
        // 将ETH数量转换为USDC价值 (1e6精度)
        // pnlInETH * currentPrice / 1e18 = USDC价值(1e6精度)
        int256 pnl = (pnlInETH * int256(currentPrice)) / 1e18;
        
        return pnl;
    }
    
    // 检查是否可以清算
    function canLiquidate(address user) public view returns (bool) {
        Position storage pos = positions[user];
        if (pos.margin == 0) return false;
        
        int256 pnl = calculatePnL(user);
        
        // 如果亏损且亏损超过保证金的10%，则可以清算
        // pnl现在是USDC价值(1e6精度)，可以直接与保证金比较
        return pnl < 0 && uint256(-pnl) >= (pos.margin * LIQUIDATION_THRESHOLD) / 100;
    }

    // 清算头寸
    function liquidatePosition(address _user) external {
        require(_user != msg.sender, "Cannot liquidate own position");
        require(canLiquidate(_user), "Position cannot be liquidated");
        
        Position storage pos = positions[_user];
        
        // 计算清算奖励
        uint256 liquidationReward = (pos.margin * LIQUIDATION_REWARD) / 100;
        
        // 恢复虚拟储备到开仓前状态
        if (pos.isLong) {
            // 做多时开仓增加了vUSDCReserve，清算时应该减少
            if (vUSDCReserve > pos.notional) {
                vUSDCReserve -= pos.notional;
            } else {
                // 如果储备不足，设置为最小值
                vUSDCReserve = 1e6; // 1 USDC
            }
            // 重新计算vETHReserve
            vETHReserve = K / vUSDCReserve;
        } else {
            // 做空时开仓减少了vUSDCReserve，清算时应该恢复
            vUSDCReserve += pos.notional;
            vETHReserve = K / vUSDCReserve;
        }
        
        // 清除仓位
        delete positions[_user];
        
        // 支付清算奖励
        USDC.transfer(msg.sender, liquidationReward);
        
        emit PositionLiquidated(_user, msg.sender, liquidationReward);
    }
}