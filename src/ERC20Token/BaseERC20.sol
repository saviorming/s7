pragma solidity ^0.8.25;

import "forge-std/console.sol";


contract BaseERC20{
    //名字
    string public name;
    //token符号
    string public symbol;
    //token精度
    uint8 public decimals;
    //总供应量
    uint256 public totalSupply;

    mapping(address => uint256) balances;

    mapping (address => mapping (address => uint256)) allowances;
    //转款事件
    event Transfer(address indexed from, address indexed to, uint256 value);
    //授权事件
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // 设置名字，符号，精度，总供应量
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 100000000; // 确保总供应量考虑到精度
        balances[msg.sender] = totalSupply; // 将总供应量分配给合约创建者
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        // 返回指定地址的余额
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success){
        require(balances[msg.sender] >= _value,"ERC20: transfer amount exceeds balance");
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        // write your code here
        require(_spender != address(0),"ERC20: approve to the zero address");
        allowances[msg.sender][_spender] = _value; 
        emit Approval(msg.sender, _spender, _value); 
        return true; 
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {   
        // write your code here
        require(_owner != address(0),"ERC20: allowance to the zero address");
        require(_spender != address(0),"ERC20: allowance to the zero address");
        return allowances[_owner][_spender];
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // write your code here
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");
        require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");
        require(allowances[_from][msg.sender] >= _value,"ERC20: transfer amount exceeds allowance");
        balances[_from] -= _value; 
        balances[_to] += _value;
        allowances[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value); 
        return true; 
    }
    

}