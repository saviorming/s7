// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ReleaseToken
 * @dev 可释放的代币合约,初始化100W个，用于后续给Vesting合约线性解锁
 */ 
contract ReleaseToken is ERC20, Ownable {
    constructor() ERC20("ReleaseToken", "RT") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

/**
 * @title Vesting
 * @dev 代币线性释放合约，支持按时间线性释放代币给受益人
 */
contract Vesting is Ownable {
    // 受益人地址
    address public immutable _beneficiary;
    // 释放的token
    IERC20 public immutable _releaseToken;
    // 合约启动时间
    uint256 public immutable _start;
    // 总释放代币数量（100万代币，已考虑小数位）
    uint256 public immutable _totalVestingAmount;
    // 已释放的代币数量
    uint256 public _released;
    //悬崖时间
    uint256 public immutable _cLiffDays;
    //时间常量相关
    //奖励领取间隔时间
    uint256 public immutable _vestingDays;
    // 解锁持续时间
    uint256 public immutable _durationDays;

    // 事件
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary, uint256 unreleased);

    /**
     * @dev 构造函数
     * @param releaseToken 要释放的代币合约地址
     * @param duration 释放持续时间（天）- 此参数暂未使用，保持兼容性
     * @param beneficiary 受益人地址
     * @param cLiffDays 锁定期（天）
     * @param vestingDays 每次释放间隔（天）- 此参数暂未使用
     * @param durationDays 线性释放总时长（天）
     */
    constructor(
        address releaseToken, 
        uint64 duration, 
        address beneficiary,
        uint256 cLiffDays,
        uint256 vestingDays,
        uint256 durationDays
    ) Ownable(msg.sender) {
        require(releaseToken != address(0), "Token address cannot be zero");
        require(beneficiary != address(0), "Beneficiary cannot be zero");
        require(duration > 0, "Duration must be greater than 0");
        _releaseToken = IERC20(releaseToken);
        _start = block.timestamp;
        _beneficiary = beneficiary;
        _totalVestingAmount = 1_000_000 * 10 ** 18;
        _cLiffDays = cLiffDays * 1 days;
        _vestingDays = vestingDays * 1 days;
        _durationDays = durationDays * 1 days;
        // 代币转移将在单独的函数中处理
    }

    /**
     * @dev 初始化代币转移（只能调用一次）
     */
    function initializeTokens() external onlyOwner {
        require(_releaseToken.balanceOf(address(this)) == 0, "Tokens already initialized");
        bool success = _releaseToken.transferFrom(
            msg.sender,
            address(this),
            _totalVestingAmount
        );
        require(success, "Transfer failed");
    }


    /**
     * @dev 查看剩余未释放的代币数量
     */
    function remaining() public view returns (uint256) {
        return _totalVestingAmount - _released;
    }
    
    /**
     * @dev 计算当前时间已归属的代币总量
     * 逻辑：12个月锁定期 + 24个月线性释放
     */
    function vested() private view returns (uint256) {
        // 锁定期内（12个月内）：0释放
        if (block.timestamp < _start + _cLiffDays) {
            return 0;
        } 
        // 超过总周期（12+24=36个月后）：全部归属
        if (block.timestamp >= _start + _cLiffDays + _durationDays) {
            return _totalVestingAmount;
        } 
        // 释放期内：按时间比例线性计算
        // 从第13个月开始，24个月内线性释放
        uint256 timeElapsed = block.timestamp - (_start + _cLiffDays);
        uint256 vestedAmount = (_totalVestingAmount * timeElapsed) / _durationDays;
        return vestedAmount;
    }
    //计算当前时间可领取的代币数量
    function releasable() public view returns (uint256) {
        uint256 vestedAmount = vested();
        if (vestedAmount <= _released) {
            return 0;
        }
        return vestedAmount - _released;
    }

    /**
     * @dev 释放当前可解锁的代币给受益人
     * 只有受益人或合约所有者可以调用
     */
    function release() external {
        require(msg.sender == _beneficiary || msg.sender == owner(), "Only beneficiary or owner can release");
        
        uint256 releasableAmount = releasable();
        require(releasableAmount > 0, "No tokens available to release");
        
        _released += releasableAmount;
        
        bool success = _releaseToken.transfer(_beneficiary, releasableAmount);
        require(success, "Token transfer failed");
        
        emit TokensReleased(_beneficiary, releasableAmount);
    }

    /**
     * @dev 紧急撤销功能（仅限所有者）
     * 将所有未释放的代币返还给所有者
     */
    function revoke() external onlyOwner {
        uint256 unreleased = remaining();
        require(unreleased > 0, "No tokens to revoke");

        _released = _totalVestingAmount; // 标记为全部已释放，防止后续释放
        
        bool success = _releaseToken.transfer(owner(), unreleased);
        require(success, "Token transfer failed");

        emit VestingRevoked(_beneficiary, unreleased);
    }

    /**
     * @dev 获取合约基本信息
     */
    function getVestingInfo() external view returns (
        address beneficiary,
        address token,
        uint256 start,
        uint256 cliffDays,
        uint256 durationDays,
        uint256 totalAmount,
        uint256 released,
        uint256 releasableNow
    ) {
        return (
            _beneficiary,
            address(_releaseToken),
            _start,
            _cLiffDays / 1 days,
            _durationDays / 1 days,
            _totalVestingAmount,
            _released,
            releasable()
        );
    }

}