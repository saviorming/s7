// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {ExtendedERC20} from "src/ExtendedERC20/ExtendedERC20.sol";

contract ExtendedERC20Test is Test {
    ExtendedERC20 token;
    address user = address(0x1);

    function setUp() public {
        token = new ExtendedERC20();
        //vm.prank(token.owner());
        token.transfer(user, 1000 ether);
    }

    function testTransferWithCallbackToEOA() public {
        vm.prank(user);
        bool success = token.transferWithCallback(address(0x2), 1 ether, "");
        assertTrue(success);
        assertEq(token.balanceOf(address(0x2)), 1 ether);
    }

    // 可以补充更多合约地址的回调测试
}