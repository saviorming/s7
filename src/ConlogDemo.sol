pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/console.sol";

contract ConlogDemo {
    uint256 public x;

    function getLog() public  returns(uint256){
        x = 1;
        console.log("Hello, World!");
        return x;
    }

    function increment() public{
        console.log("x is", x);
        x++;
        console.log("x is", x);
    }
    
    function incrementIput(uint256 _x) public pure returns(uint256){
        _x = _x+1;
        console.log("_x is ",_x);
        return _x;
    }
}