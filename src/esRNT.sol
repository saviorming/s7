pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract esRNTP{
    struct Lockinfo{
        address user;
        uint64 startTime;
        uint256 amount;
    }
    Lockinfo[] private _locks;
    
    constructor(){
       for(uint256 i=0;i<11;i++){
            _locks.push(Lockinfo(address(uint160(i+1)), uint64(block.timestamp*2-i), 1e18*(i+1)));
       }
    }
}