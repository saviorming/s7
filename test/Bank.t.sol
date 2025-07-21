// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/Bank.sol";

contract BankTest is Test {
    Bank public bank;
    address public admin;
    address public user1;
    address public user2;
    address public user3;
    address public user4;

    function setUp() public {
        admin = address(0xA1);
        user1 = address(0xB1);
        user2 = address(0xB2);
        user3 = address(0xB3);
        user4 = address(0xB4);
        bank = new Bank(admin);
    }

    // 1. 存款前后余额断言
    function test_DepositUpdatesBalance() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        assertEq(bank.balances(user1), 1 ether);

        vm.prank(user1);
        bank.deposit{value: 2 ether}();
        assertEq(bank.balances(user1), 3 ether);
    }

    // 2. 前3名用户检查（1个用户）
    function test_TopDepositors_OneUser() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        address[3] memory top = bank.getTop();
        assertEq(top[0], user1);
        assertEq(top[1], address(0));
        assertEq(top[2], address(0));
    }

    // 3. 前3名用户检查（2个用户）
    function test_TopDepositors_TwoUsers() public {
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        vm.prank(user2);
        bank.deposit{value: 2 ether}();

        address[3] memory top = bank.getTop();
        assertEq(top[0], user2);
        assertEq(top[1], user1);
        assertEq(top[2], address(0));
    }

    // 4. 前3名用户检查（3个用户）
    function test_TopDepositors_ThreeUsers() public {
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        vm.prank(user2);
        bank.deposit{value: 3 ether}();
        vm.prank(user3);
        bank.deposit{value: 2 ether}();

        address[3] memory top = bank.getTop();
        assertEq(top[0], user2);
        assertEq(top[1], user3);
        assertEq(top[2], user1);
    }

    // 5. 前3名用户检查（4个用户，淘汰最小的）
    function test_TopDepositors_FourUsers() public {
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);

        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        vm.prank(user2);
        bank.deposit{value: 3 ether}();
        vm.prank(user3);
        bank.deposit{value: 2 ether}();
        vm.prank(user4);
        bank.deposit{value: 4 ether}();

        address[3] memory top = bank.getTop();
        assertEq(top[0], user4);
        assertEq(top[1], user2);
        assertEq(top[2], user3);
        // user1 被淘汰
    }

    // 6. 同一用户多次存款
    function test_TopDepositors_SameUserMultipleDeposits() public {
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        vm.prank(user2);
        bank.deposit{value: 2 ether}();
        vm.prank(user3);
        bank.deposit{value: 3 ether}();

        // user1 再存 3 ether，总额 4 ether，应该排第一
        vm.prank(user1);
        bank.deposit{value: 3 ether}();

        address[3] memory top = bank.getTop();
        assertEq(top[0], user1);
        assertEq(top[1], user3);
        assertEq(top[2], user2);
    }

    // 7. 只有管理员可取款
    function test_OnlyAdminCanWithdraw() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        bank.deposit{value: 1 ether}();

        // 非管理员取款应revert
        vm.prank(user1);
        vm.expectRevert();
        bank.withdraw(1 ether);

        // 管理员可以取款
        vm.prank(admin);
        bank.withdraw(1 ether);
        // 合约余额应为0
        assertEq(address(bank).balance, 0);
    }
} 