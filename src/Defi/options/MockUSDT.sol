// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MockUSDT
 * @dev 模拟USDT代币，用于与期权Token创建交易对
 * @notice 这是一个测试用的USDT代币，具有铸造和销毁功能
 */
contract MockUSDT is ERC20, Ownable {
    
    // USDT通常使用6位小数
    uint8 private constant DECIMALS = 6;
    
    // 事件
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    
    /**
     * @dev 构造函数
     * @param _initialSupply 初始供应量 (考虑小数位)
     */
    constructor(uint256 _initialSupply) ERC20("Mock USDT", "USDT") Ownable(msg.sender) {
        // 铸造初始供应量给部署者
        _mint(msg.sender, _initialSupply * 10**DECIMALS);
    }
    
    /**
     * @dev 重写decimals函数，返回6位小数
     * @return uint8 小数位数
     */
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
    
    /**
     * @dev 铸造代币（仅限所有者）
     * @param _to 接收地址
     * @param _amount 铸造数量（不包含小数位）
     */
    function mint(address _to, uint256 _amount) external onlyOwner {
        uint256 amountWithDecimals = _amount * 10**DECIMALS;
        _mint(_to, amountWithDecimals);
        emit TokensMinted(_to, amountWithDecimals);
    }
    
    /**
     * @dev 销毁代币
     * @param _amount 销毁数量（包含小数位）
     */
    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
        emit TokensBurned(msg.sender, _amount);
    }
    
    /**
     * @dev 从指定地址销毁代币（需要授权）
     * @param _from 销毁地址
     * @param _amount 销毁数量（包含小数位）
     */
    function burnFrom(address _from, uint256 _amount) external {
        uint256 currentAllowance = allowance(_from, msg.sender);
        require(currentAllowance >= _amount, "ERC20: burn amount exceeds allowance");
        
        _approve(_from, msg.sender, currentAllowance - _amount);
        _burn(_from, _amount);
        emit TokensBurned(_from, _amount);
    }
    
    /**
     * @dev 批量转账
     * @param _recipients 接收者地址数组
     * @param _amounts 转账金额数组
     */
    function batchTransfer(address[] calldata _recipients, uint256[] calldata _amounts) external {
        require(_recipients.length == _amounts.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < _recipients.length; i++) {
            transfer(_recipients[i], _amounts[i]);
        }
    }
    
    /**
     * @dev 获取用户余额（以USDT为单位，不包含小数位）
     * @param _account 查询地址
     * @return uint256 余额（USDT单位）
     */
    function balanceOfUSDT(address _account) external view returns (uint256) {
        return balanceOf(_account) / 10**DECIMALS;
    }
    
    /**
     * @dev 转账（以USDT为单位，不包含小数位）
     * @param _to 接收地址
     * @param _amountUSDT 转账金额（USDT单位）
     * @return bool 是否成功
     */
    function transferUSDT(address _to, uint256 _amountUSDT) external returns (bool) {
        uint256 amountWithDecimals = _amountUSDT * 10**DECIMALS;
        return transfer(_to, amountWithDecimals);
    }
    
    /**
     * @dev 授权转账（以USDT为单位，不包含小数位）
     * @param _from 发送地址
     * @param _to 接收地址
     * @param _amountUSDT 转账金额（USDT单位）
     * @return bool 是否成功
     */
    function transferFromUSDT(address _from, address _to, uint256 _amountUSDT) external returns (bool) {
        uint256 amountWithDecimals = _amountUSDT * 10**DECIMALS;
        return transferFrom(_from, _to, amountWithDecimals);
    }
    
    /**
     * @dev 授权（以USDT为单位，不包含小数位）
     * @param _spender 被授权地址
     * @param _amountUSDT 授权金额（USDT单位）
     * @return bool 是否成功
     */
    function approveUSDT(address _spender, uint256 _amountUSDT) external returns (bool) {
        uint256 amountWithDecimals = _amountUSDT * 10**DECIMALS;
        return approve(_spender, amountWithDecimals);
    }
    
    /**
     * @dev 查询授权额度（以USDT为单位，不包含小数位）
     * @param _owner 所有者地址
     * @param _spender 被授权地址
     * @return uint256 授权额度（USDT单位）
     */
    function allowanceUSDT(address _owner, address _spender) external view returns (uint256) {
        return allowance(_owner, _spender) / 10**DECIMALS;
    }
    
    /**
     * @dev 紧急暂停功能（可扩展）
     * @notice 预留接口，可在需要时实现暂停功能
     */
    function pause() external onlyOwner {
        // 可以在这里实现暂停逻辑
        // 例如：_pause(); (需要导入Pausable)
    }
    
    /**
     * @dev 恢复功能（可扩展）
     * @notice 预留接口，可在需要时实现恢复功能
     */
    function unpause() external onlyOwner {
        // 可以在这里实现恢复逻辑
        // 例如：_unpause(); (需要导入Pausable)
    }
}