// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {ExtendedERC20} from "src/ExtendedERC20/ExtendedERC20.sol";
import {TokenBankV2} from "src/ExtendedERC20/TokenBankV2.sol";

contract TokenBankV2Test is Test {
    ExtendedERC20 token;
    TokenBankV2 bank;
    address user = address(0x1);

    function setUp() public {
        token = new ExtendedERC20();
        bank = new TokenBankV2(address(token));
        token.transfer(user, 1000 ether);
    }

    function testDepositWithCallback() public {
        vm.prank(user);
        // 用户调用扩展ERC20的transferWithCallback存入TokenBankV2
        token.approve(address(bank), 100 ether); // approve不是必须，但可以测试兼容性
        vm.prank(user);
        bool success = token.transferWithCallback(address(bank), 100 ether, "");
        assertTrue(success);
        assertEq(bank.balances(user), 100 ether);
    }

    function testWithdraw() public {
        vm.prank(user);
        token.transferWithCallback(address(bank), 50 ether, "");
        vm.prank(user);
        bank.withdraw(20 ether);
        assertEq(bank.balances(user), 30 ether);
        assertEq(token.balanceOf(user), 1000 ether - 50 ether + 20 ether);
    }
}