pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/ExtendedERC20/AirdopMerkleNFTMarket.sol";
import "../src/ExtendedERC20/ExtendedERC20WithPermit.sol";
import "../src/ExtendedERC20/SimpleNFT.sol";

contract AirdopMerkleNFTMarketScript is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 Token 合约（支持 permit）
        ExtendedERC20WithPermit token = new ExtendedERC20WithPermit();
        console.log("Token deployed at:", address(token));
        
        // 2. 部署 NFT 合约
        SimpleNFT nft = new SimpleNFT();
        console.log("NFT deployed at:", address(nft));
        
        // 3. 创建 Merkle Root（示例：包含几个白名单地址）
        // 在实际应用中，你需要使用专门的工具来生成 Merkle Tree
        address[] memory whitelist = new address[](3);
        whitelist[0] = 0x1234567890123456789012345678901234567890;
        whitelist[1] = 0x2345678901234567890123456789012345678901;
        whitelist[2] = 0x3456789012345678901234567890123456789012;
        
        // 简化的 Merkle Root 计算（实际应用中需要更复杂的实现）
        bytes32 merkleRoot = keccak256(abi.encodePacked(whitelist[0], whitelist[1], whitelist[2]));
        
        // 4. 部署 AirdopMerkleNFTMarket 合约
        AirdopMerkleNFTMarket market = new AirdopMerkleNFTMarket(address(token), merkleRoot);
        console.log("AirdopMerkleNFTMarket deployed at:", address(market));
        
        // 5. 初始化设置
        // 铸造一些 NFT 用于测试
        nft.mint(msg.sender);
        nft.mint(msg.sender);
        nft.mint(msg.sender);
        console.log("Minted 3 NFTs to deployer");
        
        // 6. 上架一个 NFT
        nft.approve(address(market), 0);
        market.list(address(nft), 0, 100 * 10**18); // 100 tokens
        console.log("Listed NFT #0 for 100 tokens");
        
        // 7. 显示合约信息
        console.log("=== Contract Information ===");
        console.log("Token Name:", token.name());
        console.log("Token Symbol:", token.symbol());
        console.log("NFT Name:", nft.name());
        console.log("NFT Symbol:", nft.symbol());
        console.log("Merkle Root:", vm.toString(merkleRoot));
        
        // 8. 显示上架信息
        uint256[] memory activeListings = market.getActiveListings();
        console.log("Active Listings Count:", activeListings.length);
        
        if (activeListings.length > 0) {
            (address seller, address nftAddress, uint256 tokenId, uint256 price, bool isActive,) = 
                market.nfts(activeListings[0]);
            console.log("First Listing - Seller:", seller);
            console.log("First Listing - NFT Address:", nftAddress);
            console.log("First Listing - Token ID:", tokenId);
            console.log("First Listing - Price:", price);
            console.log("First Listing - Discounted Price:", market.getDiscountedPrice(activeListings[0]));
        }
        
        vm.stopBroadcast();
        
        // 9. 显示使用说明
        console.log("\n=== Usage Instructions ===");
        console.log("1. For regular users:");
        console.log("   - Approve tokens: token.approve(marketAddress, amount)");
        console.log("   - Buy NFT: market.buyNFT(listingId)");
        console.log("");
        console.log("2. For whitelist users (50% discount):");
        console.log("   - Generate Merkle proof for your address");
        console.log("   - Use permitAndClaimNFT() for one-transaction purchase");
        console.log("   - Or use multicall with permitPrePay() + claimNFT()");
        console.log("");
        console.log("3. For sellers:");
        console.log("   - Approve NFT: nft.approve(marketAddress, tokenId)");
        console.log("   - List NFT: market.list(nftAddress, tokenId, price)");
        console.log("   - Delist NFT: market.delist(listingId)");
    }
    
    // 辅助函数：生成简单的 Merkle Proof（仅用于演示）
    function generateSimpleMerkleProof(address user, address[] memory whitelist) 
        public pure returns (bytes32[] memory) {
        // 这是一个简化的实现，实际应用中需要使用专门的 Merkle Tree 库
        bytes32[] memory proof = new bytes32[](0);
        return proof;
    }
}