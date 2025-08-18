// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OptionTradingPair
 * @dev 期权Token与USDT的交易对合约，允许用户用USDT购买期权Token
 */
contract OptionTradingPair is Ownable, ReentrancyGuard {
    IERC20 public immutable optionToken;
    IERC20 public immutable usdt;
    
    // 期权Token的价格（以USDT计价，18位精度）
    uint256 public optionPrice;
    
    // 事件
    event OptionPurchased(address indexed buyer, uint256 usdtAmount, uint256 optionAmount);
    event OptionSold(address indexed seller, uint256 optionAmount, uint256 usdtAmount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event LiquidityAdded(uint256 optionAmount, uint256 usdtAmount);
    event LiquidityRemoved(uint256 optionAmount, uint256 usdtAmount);
    
    // 错误
    error ZeroAmount();
    error InsufficientBalance();
    error TransferFailed();
    error ZeroAddress();
    error InvalidPrice();
    
    /**
     * @dev 构造函数
     * @param _optionToken 期权Token合约地址
     * @param _usdt USDT合约地址
     * @param _initialPrice 初始期权价格（以USDT计价）
     */
    constructor(
        address _optionToken,
        address _usdt,
        uint256 _initialPrice
    ) Ownable(msg.sender) {
        if (_optionToken == address(0) || _usdt == address(0)) {
            revert ZeroAddress();
        }
        if (_initialPrice == 0) {
            revert InvalidPrice();
        }
        
        optionToken = IERC20(_optionToken);
        usdt = IERC20(_usdt);
        optionPrice = _initialPrice;
    }
    
    /**
     * @dev 用户用USDT购买期权Token
     * @param usdtAmount 支付的USDT数量
     */
    function buyOptions(uint256 usdtAmount) external nonReentrant {
        if (usdtAmount == 0) {
            revert ZeroAmount();
        }
        
        // 计算可购买的期权Token数量
        uint256 optionAmount = (usdtAmount * 1e18) / optionPrice;
        
        // 检查合约是否有足够的期权Token
        if (optionToken.balanceOf(address(this)) < optionAmount) {
            revert InsufficientBalance();
        }
        
        // 转入USDT
        if (!usdt.transferFrom(msg.sender, address(this), usdtAmount)) {
            revert TransferFailed();
        }
        
        // 转出期权Token
        if (!optionToken.transfer(msg.sender, optionAmount)) {
            revert TransferFailed();
        }
        
        emit OptionPurchased(msg.sender, usdtAmount, optionAmount);
    }
    
    /**
     * @dev 用户卖出期权Token换取USDT
     * @param optionAmount 卖出的期权Token数量
     */
    function sellOptions(uint256 optionAmount) external nonReentrant {
        if (optionAmount == 0) {
            revert ZeroAmount();
        }
        
        // 计算可获得的USDT数量 (转换为USDT的6位小数)
        uint256 usdtAmount = (optionAmount * optionPrice) / 1e30; // 1e18 (期权) * 1e18 (价格) / 1e30 = 1e6 (USDT)
        
        // 检查合约是否有足够的USDT
        if (usdt.balanceOf(address(this)) < usdtAmount) {
            revert InsufficientBalance();
        }
        
        // 转入期权Token
        if (!optionToken.transferFrom(msg.sender, address(this), optionAmount)) {
            revert TransferFailed();
        }
        
        // 转出USDT
        if (!usdt.transfer(msg.sender, usdtAmount)) {
            revert TransferFailed();
        }
        
        emit OptionSold(msg.sender, optionAmount, usdtAmount);
    }
    
    /**
     * @dev 设置期权价格（仅所有者）
     * @param newPrice 新的期权价格
     */
    function setOptionPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) {
            revert InvalidPrice();
        }
        
        uint256 oldPrice = optionPrice;
        optionPrice = newPrice;
        
        emit PriceUpdated(oldPrice, newPrice);
    }
    
    /**
     * @dev 添加流动性（仅所有者）
     * @param optionAmount 添加的期权Token数量
     * @param usdtAmount 添加的USDT数量
     */
    function addLiquidity(uint256 optionAmount, uint256 usdtAmount) external onlyOwner {
        if (optionAmount == 0 && usdtAmount == 0) {
            revert ZeroAmount();
        }
        
        if (optionAmount > 0) {
            if (!optionToken.transferFrom(msg.sender, address(this), optionAmount)) {
                revert TransferFailed();
            }
        }
        
        if (usdtAmount > 0) {
            if (!usdt.transferFrom(msg.sender, address(this), usdtAmount)) {
                revert TransferFailed();
            }
        }
        
        emit LiquidityAdded(optionAmount, usdtAmount);
    }
    
    /**
     * @dev 移除流动性（仅所有者）
     * @param optionAmount 移除的期权Token数量
     * @param usdtAmount 移除的USDT数量
     */
    function removeLiquidity(uint256 optionAmount, uint256 usdtAmount) external onlyOwner {
        if (optionAmount == 0 && usdtAmount == 0) {
            revert ZeroAmount();
        }
        
        if (optionAmount > 0) {
            if (optionToken.balanceOf(address(this)) < optionAmount) {
                revert InsufficientBalance();
            }
            if (!optionToken.transfer(msg.sender, optionAmount)) {
                revert TransferFailed();
            }
        }
        
        if (usdtAmount > 0) {
            if (usdt.balanceOf(address(this)) < usdtAmount) {
                revert InsufficientBalance();
            }
            if (!usdt.transfer(msg.sender, usdtAmount)) {
                revert TransferFailed();
            }
        }
        
        emit LiquidityRemoved(optionAmount, usdtAmount);
    }
    
    /**
     * @dev 获取购买期权所需的USDT数量
     * @param optionAmount 期权Token数量
     * @return 所需的USDT数量
     */
    function getUsdtRequired(uint256 optionAmount) external view returns (uint256) {
        return (optionAmount * optionPrice) / 1e18;
    }
    
    /**
     * @dev 获取USDT可购买的期权Token数量
     * @param usdtAmount USDT数量
     * @return 可购买的期权Token数量
     */
    function getOptionAmount(uint256 usdtAmount) external view returns (uint256) {
        return (usdtAmount * 1e18) / optionPrice;
    }
    
    /**
     * @dev 获取合约中的期权Token余额
     */
    function getOptionBalance() external view returns (uint256) {
        return optionToken.balanceOf(address(this));
    }
    
    /**
     * @dev 获取合约中的USDT余额
     */
    function getUsdtBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }
}