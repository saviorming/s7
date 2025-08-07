// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/NftMark/BasicVersion/NFTMarket.sol";
import "../src/NftMark/BasicVersion/BaseErc20Token.sol";
import "../src/NftMark/BasicVersion/BaseNft.sol";

contract NFTMarketExampleScript is Script {
    NFTMarket public market;
    BaseErc20Token public token;
    BaseNft public nft;
    
    address public seller = 0x1234567890123456789012345678901234567890;
    address public buyer = 0x2345678901234567890123456789012345678901;
    
    function run() public {
        vm.startPrank(seller);
        
        console.log("=== NFT Market Example ===");
        
        // Deploy contracts
        token = new BaseErc20Token();
        nft = new BaseNft("ExampleNFT", "ENFT");
        market = new NFTMarket(address(token));
        
        console.log("Contracts deployed:");
        console.log("Token:", address(token));
        console.log("NFT:", address(nft));
        console.log("Market:", address(market));
        
        // Initialize test data
        token.mint(seller, 1000 * 10**18);
        token.mint(buyer, 1000 * 10**18);
        nft.mint(seller);
        
        console.log("=== Initialize Test Data ===");
        console.log("Seller token balance:", token.balanceOf(seller));
        console.log("Buyer token balance:", token.balanceOf(buyer));
        console.log("NFT owner:", nft.ownerOf(0));
        
        // List NFT
        nft.approve(address(market), 0);
        market.list(address(nft), 0, 100 * 10**18);
        
        console.log("=== NFT Listed ===");
        console.log("Active listings count:", market.nftCount());
        
        NFTMarket.NFTinfo memory nftInfo = market.getNFTInfo(0);
        console.log("NFT price:", nftInfo.price);
        console.log("NFT is active:", nftInfo.isActive);
        
        vm.stopPrank();
        
        // Buy NFT
        vm.startPrank(buyer);
        token.approve(address(market), 100 * 10**18);
        market.buyNFT(0);
        
        console.log("=== NFT Purchased ===");
        console.log("New NFT owner:", nft.ownerOf(0));
        console.log("Seller token balance:", token.balanceOf(seller));
        console.log("Buyer token balance:", token.balanceOf(buyer));
        console.log("Active listings count:", market.nftCount());
        
        vm.stopPrank();
        
        console.log("=== Example Complete ===");
    }
}