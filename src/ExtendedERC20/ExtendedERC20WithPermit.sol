pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

//定义回调接口
interface IERC20Callback {
    function tokensReceived(address sender, uint256 amount, bytes memory data) external;
}

contract ExtendedERC20WithPermit is ERC20, ERC20Permit {

    constructor() ERC20("ExtendedERC20WithPermit", "EERC20P") ERC20Permit("ExtendedERC20WithPermit") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    event CallbackFailed(address indexed to);
    event CallbackSuccess(address indexed to, uint256 amount, bytes data);

    //拓展函数：有hook 功能的转账函数
    //在转账时，如果目标地址是合约地址的话，调用目标地址的 tokensReceived() 方法
    function transferWithCallback(address _to, uint256 _value, bytes memory _data)
    external returns (bool success)
    {
        //执行转账，验证金额跟地址
        require(balanceOf(msg.sender) >= _value, "ERC20: transfer amount exceeds balance");
        require(_to != address(0), "ERC20: transfer to the zero address");
        _transfer(msg.sender, _to, _value);
        //判断目标是否是合约地址
        if (isContract(_to)) {
            try IERC20Callback(_to).tokensReceived(msg.sender, _value, _data){
               emit CallbackSuccess(_to, _value, _data);
            } catch{
                emit CallbackFailed(_to);
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
}