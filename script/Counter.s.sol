// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Counter} from "../src/Counter.sol";

contract CounterScript is Script {
    Counter public counter;

    function setUp() public {}

    function run() public {
        // 1. 部署者私钥（Anvil 本地节点默认第一个账户私钥，含 1000 ETH）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        counter = new Counter();
        vm.stopBroadcast();
                // ======== 输出结果 ========
        console.log(unicode"CounterScript depoly success！");
        console.log(unicode"合约地址：", address(counter));
        console.log(unicode"部署者地址：", vm.addr(deployerPrivateKey));
    }
}
