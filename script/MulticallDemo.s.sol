// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/NftMark/PerMitAndMutilcall/AirdopMerkleNFTMarket.sol";
import "../src/NftMark/PerMitAndMutilcall/Erc20TokenWithPermit.sol";
import "../src/NftMark/BasicVersion/BaseNft.sol";

contract MulticallDemoScript is Script {
    function run() external {
        console.log("=== AirdopMerkleNFTMarket Multicall Demo ===");
        
        // 部署合约
        Erc20TokenWithPermit token = new Erc20TokenWithPermit();
        BaseNft nft = new BaseNft("DemoNFT", "DNFT");
        
        // 创建简单的 Merkle 根（单个用户）
        address buyer = address(0x123);
        bytes32 merkleRoot = keccak256(abi.encodePacked(buyer));
        address admin = address(0x456);
        
        AirdopMerkleNFTMarket market = new AirdopMerkleNFTMarket(address(token), merkleRoot, admin);
        
        console.log("Contracts deployed:");
        console.log("Token:", address(token));
        console.log("NFT:", address(nft));
        console.log("Market:", address(market));
        console.log("Merkle Root:", vm.toString(merkleRoot));
        
        console.log("\n=== Multicall Features ===");
        console.log("1. permitPrePay() - Token authorization using permit");
        console.log("2. claimNFT() - Whitelist users buy NFT with 50% discount");
        console.log("3. multicall() - Batch execute above operations using delegatecall");
        
        console.log("\n=== Key Advantages ===");
        console.log("- Complete authorization and purchase in one transaction");
        console.log("- Save gas fees");
        console.log("- Improve user experience");
        console.log("- Support EIP-2612 permit standard");
        
        console.log("\nDemo script completed!");
    }
}