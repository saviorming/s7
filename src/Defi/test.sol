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

contract Vesting is Ownable {
    // 释放的token
    IERC20 public immutable _releaseToken;
    //开始时间
    uint64 private immutable _start;
    // 解锁时间
    uint64 private immutable _end;
    // 解锁持续时间
    uint64 private immutable _duration;
    // 受益人地址
    address public immutable _beneficiary;
    // 总释放代币数量（100万代币，已考虑小数位）
    uint256 public immutable _totalVestingAmount;
    // 已释放的代币数量
    uint256 public _released;

    constructor(address releaseToken, uint64 start, uint64 duration,address beneficiary) 
    Ownable(msg.sender) {
        _releaseToken = IERC20(releaseToken);
        _start = _start;
        _end = _start + _duration;
        _duration = _duration;
        _beneficiary = beneficiary;
        _totalVestingAmount = 1_000_000 * 10 **18;
                // 向合约转入100万代币（需确保部署者提前授权）
        bool success = IERC20(releaseToken).transferFrom(
            msg.sender,
            address(this),
            _totalVestingAmount
        );
        require(success, "Transfer failed");
    }

    /**
     * @dev 计算当前可释放的代币数量
     * @return 可释放的代币数量
     */
    function releasableAmount() public view returns (uint256) {
        return _totalVestingAmount - _released;
    } 


    



    
}
