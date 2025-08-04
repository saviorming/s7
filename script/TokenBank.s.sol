pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {TokenBank} from "../src/ERC20Token/TokenBank.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MyToken} from "../src/MyToken.sol";

contract TokenBankScript is Script{
// 部署入口函数，需用 `external` 和 `broadcast` 修饰
    function run() external {
        // ======== 配置参数 ========
        // 1. 部署者私钥（Anvil 本地节点默认第一个账户私钥，含 1000 ETH）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 2. TokenBank 构造函数参数（根据你的合约修改，无参数则留空）
        // 示例：如果 TokenBank 需要一个 ERC20 代币地址作为参数：
        // address erc20Token = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;
        
        // ======== 开始部署 ========
        // 激活部署者账户（用私钥签名交易）
        vm.startBroadcast(deployerPrivateKey);
        // 1. 部署测试 ERC20 代币
        //address erc20Token = 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0;
        ERC20 testToken = new MyToken("MyToken", "MTK");
        // 部署 TokenBank 合约（如无参数则直接 new TokenBank()）
        // 如有参数，传入：new TokenBank(erc20Token, otherParam);
        TokenBank tokenBank = new TokenBank(address(testToken));

        // 结束签名
        vm.stopBroadcast();

        // ======== 输出结果 ========
        console.log(unicode"TokenBank depoly success！");
        console.log(unicode"合约地址：", address(tokenBank));
        console.log(unicode"部署者地址：", vm.addr(deployerPrivateKey));
        console.log(unicode"测试代币地址：", address(testToken));
    }

}