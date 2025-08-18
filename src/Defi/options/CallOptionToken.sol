// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "forge-std/console.sol";

/**
 * @title CallOptionToken
 * @dev 看涨期权Token合约，实现ERC20标准的期权代币
 * @notice 用户可以购买期权Token，在到期日按行权价格兑换ETH
 */
contract CallOptionToken is ERC20, Ownable, ReentrancyGuard {
    // 期权参数
    uint256 public immutable strikePrice;      // 行权价格 (USDT, 6位小数)
    uint256 public immutable expirationTime;   // 到期时间 (timestamp)
    uint256 public immutable underlyingPrice;  // 创建时标的价格 (wei)
    IERC20 public immutable usdt;              // USDT代币合约
    
    // 合约状态
    uint256 public totalEthDeposited;          // 总ETH存款
    uint256 public totalOptionsIssued;         // 已发行期权总量
    bool public isExpired;                      // 是否已过期
    
    // 事件
    event OptionsIssued(address indexed issuer, uint256 ethAmount, uint256 optionTokens);
    event OptionsExercised(address indexed exerciser, uint256 optionTokens, uint256 ethReceived);
    event ExpiredOptionsDestroyed(uint256 optionTokensDestroyed, uint256 ethRedeemed);
    event OptionParametersSet(uint256 strikePrice, uint256 expirationTime, uint256 underlyingPrice);
    event EmergencyWithdraw(address indexed owner, uint256 amount);
    event EthReceived(address indexed sender, uint256 amount);
    event OptionTransfer(address indexed from, address indexed to, uint256 amount);
    
    // 错误定义
    error OptionExpired();
    error OptionNotExpired();
    error InsufficientEthDeposit();
    error InsufficientOptionTokens();
    error ExerciseNotAllowed();
    error InvalidParameters();
    error TransferFailed();
    error InsufficientUsdtAllowance();
    error ZeroAddress();
    error ExcessiveAmount();
    
    /**
     * @dev 构造函数
     * @param _name 期权Token名称
     * @param _symbol 期权Token符号
     * @param _strikePrice 行权价格 (USDT, 6位小数)
     * @param _expirationTime 到期时间 (timestamp)
     * @param _underlyingPrice 创建时标的价格 (wei)
     * @param _usdt USDT代币合约地址
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _strikePrice,
        uint256 _expirationTime,
        uint256 _underlyingPrice,
        address _usdt
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        if (_strikePrice == 0 || _expirationTime <= block.timestamp || _underlyingPrice == 0 || _usdt == address(0)) {
            revert InvalidParameters();
        }
        
        strikePrice = _strikePrice;
        expirationTime = _expirationTime;
        underlyingPrice = _underlyingPrice;
        usdt = IERC20(_usdt);
        
        emit OptionParametersSet(_strikePrice, _expirationTime, _underlyingPrice);
    }
    
    /**
     * @dev 发行期权Token（项目方角色）
     * @notice 项目方存入ETH，按1:1比例发行期权Token
     */
    function issueOptions() external payable onlyOwner nonReentrant {
        console.log("=== issueOptions called ===");
        console.log("msg.sender:", msg.sender);
        console.log("msg.value:", msg.value);
        console.log("block.timestamp:", block.timestamp);
        console.log("expirationTime:", expirationTime);
        
        if (block.timestamp >= expirationTime) {
            console.log("ERROR: Option expired");
            revert OptionExpired();
        }
        if (msg.value == 0) {
            console.log("ERROR: Insufficient ETH deposit");
            revert InsufficientEthDeposit();
        }
        
        // 按1:1比例发行期权Token (1 ETH = 1e18 期权Token)
        uint256 optionTokensToIssue = msg.value;
        console.log("optionTokensToIssue:", optionTokensToIssue);
        
        // 更新状态
        totalEthDeposited += msg.value;
        totalOptionsIssued += optionTokensToIssue;
        console.log("totalEthDeposited after:", totalEthDeposited);
        console.log("totalOptionsIssued after:", totalOptionsIssued);
        
        // 铸造期权Token给项目方
        _mint(owner(), optionTokensToIssue);
        console.log("Minted tokens to owner:", owner());
        console.log("Owner balance after mint:", balanceOf(owner()));
        
        emit OptionsIssued(msg.sender, msg.value, optionTokensToIssue);
        console.log("=== issueOptions completed ===");
    }
    
    /**
     * @dev 行权方法（用户角色）
     * @param _optionAmount 要行权的期权Token数量
     * @notice 用户在到期日当天可以按行权价格用USDT兑换ETH
     */
    function exerciseOptions(uint256 _optionAmount) external nonReentrant {
        console.log("=== exerciseOptions called ===");
        console.log("msg.sender:", msg.sender);
        console.log("_optionAmount:", _optionAmount);
        console.log("block.timestamp:", block.timestamp);
        console.log("expirationTime:", expirationTime);
        console.log("expirationTime + 1 days:", expirationTime + 1 days);
        console.log("user balance:", balanceOf(msg.sender));
        
        if (block.timestamp < expirationTime) {
            console.log("ERROR: Exercise not allowed - not yet expired");
            revert ExerciseNotAllowed();
        }
        if (block.timestamp > expirationTime + 1 days) {
            console.log("ERROR: Option expired - exercise window closed");
            revert OptionExpired();
        }
        if (balanceOf(msg.sender) < _optionAmount) {
            console.log("ERROR: Insufficient option tokens");
            revert InsufficientOptionTokens();
        }
        
        // 计算需要支付的USDT (期权Token数量 * 行权价格 / 1e18)
        // _optionAmount是期权Token数量(wei), strikePrice是行权价格(USDT 6位小数)
        uint256 usdtRequired = (_optionAmount * strikePrice) / 1e18;
        console.log("strikePrice:", strikePrice);
        console.log("usdtRequired:", usdtRequired);
        
        // 检查USDT授权额度
        uint256 allowance = usdt.allowance(msg.sender, address(this));
        console.log("USDT allowance:", allowance);
        if (allowance < usdtRequired) {
            console.log("ERROR: Insufficient USDT allowance");
            revert InsufficientUsdtAllowance();
        }
        
        // 从用户转入USDT
        console.log("Transferring USDT from user...");
        if (!usdt.transferFrom(msg.sender, address(this), usdtRequired)) {
            console.log("ERROR: USDT transfer failed");
            revert TransferFailed();
        }
        console.log("USDT transfer successful");
        
        // 销毁期权Token
        console.log("Burning option tokens...");
        _burn(msg.sender, _optionAmount);
        console.log("User balance after burn:", balanceOf(msg.sender));
        
        // 转移标的ETH给用户（期权Token对应的ETH数量）
        uint256 ethToTransfer = _optionAmount; // 期权Token数量就是对应的ETH数量(wei)
        console.log("Contract ETH balance:", address(this).balance);
        console.log("ETH to transfer (before adjustment):", ethToTransfer);
        if (address(this).balance < ethToTransfer) {
            ethToTransfer = address(this).balance;
            console.log("Adjusted ETH to transfer:", ethToTransfer);
        }
        
        // 转移标的ETH给用户
        console.log("Transferring ETH to user...");
        (bool transferSuccess, ) = payable(msg.sender).call{value: ethToTransfer}("");
        if (!transferSuccess) {
            console.log("ERROR: ETH transfer failed");
            revert TransferFailed();
        }
        console.log("ETH transfer successful");
        console.log("Contract ETH balance after transfer:", address(this).balance);
        
        emit OptionsExercised(msg.sender, _optionAmount, ethToTransfer);
        console.log("=== exerciseOptions completed ===");
    }
    
    /**
     * @dev 过期销毁（项目方角色）
     * @notice 到期后项目方可以销毁所有未行权的期权Token并赎回ETH
     */
    function destroyExpiredOptions() external onlyOwner nonReentrant {
        if (block.timestamp <= expirationTime + 1 days) {
            revert OptionNotExpired();
        }
        
        uint256 remainingTokens = totalSupply();
        uint256 ethToRedeem = address(this).balance;
        
        // 标记为已过期
        isExpired = true;
        
        // 销毁所有剩余的期权Token
        if (remainingTokens > 0) {
            // 获取所有持有者并销毁他们的Token
            _burn(owner(), balanceOf(owner()));
        }
        
        // 将剩余ETH转给项目方
        if (ethToRedeem > 0) {
            (bool success, ) = payable(owner()).call{value: ethToRedeem}("");
            if (!success) {
                revert TransferFailed();
            }
        }
        
        emit ExpiredOptionsDestroyed(remainingTokens, ethToRedeem);
    }
    
    /**
     * @dev 检查期权是否可以行权
     * @return bool 是否可以行权
     */
    function canExercise() external view returns (bool) {
        return block.timestamp >= expirationTime && 
               block.timestamp <= expirationTime + 1 days && 
               !isExpired;
    }
    
    /**
     * @dev 计算期权内在价值
     * @param _currentEthPrice 当前ETH价格
     * @return uint256 内在价值
     */
    function intrinsicValue(uint256 _currentEthPrice) external view returns (uint256) {
        if (_currentEthPrice > strikePrice) {
            return _currentEthPrice - strikePrice;
        }
        return 0;
    }
    
    /**
     * @dev 获取期权详细信息
     * @return _strikePrice 行权价格
     * @return _expirationTime 到期时间
     * @return _underlyingPrice 标的价格
     * @return _totalEthDeposited 总ETH存款
     * @return _totalOptionsIssued 已发行期权总量
     * @return _isExpired 是否已过期
     * @return _canExercise 是否可以行权
     */
    function getOptionDetails() external view returns (
        uint256 _strikePrice,
        uint256 _expirationTime,
        uint256 _underlyingPrice,
        uint256 _totalEthDeposited,
        uint256 _totalOptionsIssued,
        bool _isExpired,
        bool _canExercise
    ) {
        return (
            strikePrice,
            expirationTime,
            underlyingPrice,
            totalEthDeposited,
            totalOptionsIssued,
            isExpired,
            block.timestamp >= expirationTime && 
            block.timestamp <= expirationTime + 1 days && 
            !isExpired
        );
    }
    
    /**
     * @dev 获取合约ETH余额
     * @return uint256 合约中的ETH数量
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev 紧急提取函数（仅限所有者）
     * @notice 仅在紧急情况下使用
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert InsufficientEthDeposit();
        }
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) {
            revert TransferFailed();
        }
        
        emit EmergencyWithdraw(owner(), balance);
    }
    
    /**
     * @dev 接收ETH
     */
    receive() external payable {
        emit EthReceived(msg.sender, msg.value);
    }
    
    /**
     * @dev 重写transfer函数以添加事件日志
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        if (to == address(0)) {
            revert ZeroAddress();
        }
        
        bool success = super.transfer(to, amount);
        if (success) {
            emit OptionTransfer(msg.sender, to, amount);
        }
        return success;
    }
    
    /**
     * @dev 重写transferFrom函数以添加事件日志
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (to == address(0)) {
            revert ZeroAddress();
        }
        
        bool success = super.transferFrom(from, to, amount);
        if (success) {
            emit OptionTransfer(from, to, amount);
        }
        return success;
    }
}