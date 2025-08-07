pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "../BasicVersion/BaseErc20Token.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract Erc20TokenWithPermit is ERC20, ERC20Permit,Ownable{
    constructor() 
    ERC20("Erc20TokenWithPermitToken","ETP")
    ERC20Permit("Erc20TokenWithPermitToken")
    Ownable(msg.sender)
    {
        _mint(msg.sender, 1000000 * 10**18);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}