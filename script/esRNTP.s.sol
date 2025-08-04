pragma solidity ^0.8.25;

// 导入本地的forge-std库
import {Script} from "../lib/forge-std/src/Script.sol";
import {console} from "../lib/forge-std/src/console.sol";
import {esRNTP} from "../src/esRNT.sol";

contract esRNTPScript is Script{

      function run() public {
       uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        esRNTP esRNT = new esRNTP();
        // 结束签名
        vm.stopBroadcast();
        //==部署成功打印相关日志跟地址
                // ======== 输出结果 ========
        console.log(unicode"esRNTP depoly success！");
        console.log(unicode"合约地址：", address(esRNT));
        console.log(unicode"部署者地址：", vm.addr(deployerPrivateKey));
      }

}