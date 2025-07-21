pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ConlogDemo} from "../src/ConlogDemo.sol";


contract ConlogDemoTest is Test {
    ConlogDemo public conlogDemo;

    function setUp() public {
        conlogDemo = new ConlogDemo();
    }

    function test_getLog()public {
        uint256 x = conlogDemo.getLog();
        assertEq(x, 1);
    }

     function test_increment()public {
        conlogDemo.increment();
     } 

     function testFuzz_incrementIput(uint256 _x) public {  
        vm.assume(_x < type(uint256).max);
        uint256 x = conlogDemo.incrementIput(_x);
        assertEq(x,_x+1);
     }
}