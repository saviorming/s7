pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//基础版本的Nft，用于后续的NftMark合约引用
contract BaseNft is ERC721, Ownable{
    //nft的tokenId计数器
    uint256 private _nextTokenId;
    constructor(string memory name, string memory symbol) 
    ERC721(name, symbol) Ownable(msg.sender){}

    event Mint(address indexed to, uint256 indexed tokenId);

    //min nft
    function mint(address to) external onlyOwner returns(uint256){
        uint256 tokenId = _nextTokenId;
        _mint(to, tokenId);
        _nextTokenId++;
        emit Mint(to, tokenId);
        return tokenId;
    }

    //批量mint
    function batchMint(address to,uint256 count) external onlyOwner(){
        for (uint256 i=0; i < count; i++){
            uint256 tokenId = _nextTokenId;
            _mint(to, tokenId);
            _nextTokenId++;
            emit Mint(to, tokenId);
        }
    }
}