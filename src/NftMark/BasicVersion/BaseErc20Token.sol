pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//定义回调接口
interface IERC20Callback {
    function tokensReceived(address sender, uint256 amount, bytes memory data) external;
}

contract BaseErc20Token is ERC20, Ownable{
    constructor() ERC20("BaseErc20Token","BET") Ownable(msg.sender){
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    event CallbackFailed(address indexed to, uint256 amount, bytes data);
    event CallbackSuccess(address indexed to, uint256 amount, bytes data);

    //拓展函数：有hook 功能的转账函数
    //在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法
    function transferWithCallback(address _to,uint256 _value,bytes memory _data) external returns(bool success){
        //先做对应的验证，虽然transfer已经做了相关的验证了
        require(_to != address(0),"address is not valid");
        require(_to != msg.sender,"can't transfer to self");
        require(_value > 0,"value must be greater than 0");
        require(balanceOf(msg.sender) >= _value,"balance is not enough");
        
        // 先进行转账
        _transfer(msg.sender, _to, _value);
        //验证目标地址是否是合约地址,如果是合约地址，则调用对应的tokensReceived方法
        if(isContract(_to)){
            try IERC20Callback(_to).tokensReceived(msg.sender,_value,_data){
                emit CallbackSuccess(_to,_value,_data);
            }catch {
                emit CallbackFailed(_to, _value, _data);
            }
        }
        return true;
    }

    function isContract(address _to) internal view returns (bool){
         // 根据extcodesize判断，但构造函数执行期间会返回0
        uint256 size;
        assembly {
            size := extcodesize(_to)
        }
        return size > 0;
    }
    
    // 添加 mint 函数用于测试
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

