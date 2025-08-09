pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NftMark/Upgrade/NftUpgradeV2.sol";
import "../src/NftMark/Upgrade/NFTMarketplaceV2.sol";
import "../src/NftMark/Upgrade/NFTMarketplaceV1.sol";

contract UpgradeToV2 is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // 这些地址需要从之前的部署中获取
        address nftProxyAddress = vm.envAddress("NFT_PROXY_ADDRESS");
        address marketProxyAddress = vm.envAddress("MARKET_PROXY_ADDRESS");
        
        console.log("Upgrader address:", deployer);
        console.log("NFT Proxy address:", nftProxyAddress);
        console.log("Market Proxy address:", marketProxyAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 NFT V2 实现合约
        console.log("Deploying NFT V2 Implementation...");
        NftUpgradeV2 nftV2Implementation = new NftUpgradeV2();
        console.log("NFT V2 Implementation deployed at:", address(nftV2Implementation));
        
        // 2. 升级 NFT 合约到 V2
        console.log("Upgrading NFT to V2...");
        NftUpgradeV1 nftProxy = NftUpgradeV1(nftProxyAddress);
        nftProxy.upgradeToAndCall(
            address(nftV2Implementation),
            abi.encodeWithSelector(NftUpgradeV2.upgradeInitialize.selector, true)
        );
        console.log("NFT upgraded to V2 successfully");
        
        // 3. 部署市场 V2 实现合约
        console.log("Deploying Market V2 Implementation...");
        NFTMarketplaceV2 marketV2Implementation = new NFTMarketplaceV2();
        console.log("Market V2 Implementation deployed at:", address(marketV2Implementation));
        
        // 4. 升级市场合约到 V2
        console.log("Upgrading Market to V2...");
        NFTMarketplaceV1 marketProxy = NFTMarketplaceV1(marketProxyAddress);
        marketProxy.upgradeToAndCall(
            address(marketV2Implementation),
            abi.encodeWithSelector(NFTMarketplaceV2.initializeV2.selector)
        );
        console.log("Market upgraded to V2 successfully");
        
        vm.stopBroadcast();
        
        // 验证升级
        console.log("=== Upgrade Verification ===");
        NftUpgradeV2 nftV2 = NftUpgradeV2(nftProxyAddress);
        NFTMarketplaceV2 marketV2 = NFTMarketplaceV2(marketProxyAddress);
        
        console.log("NFT V2 URI fallback enabled:", nftV2.uriFallbackToBase());
        console.log("Market V2 user nonce for deployer:", marketV2.getUserNonce(deployer));
        
        // 保存升级信息
        string memory upgradeInfo = string(abi.encodePacked(
            "NFT V2 Implementation: ", vm.toString(address(nftV2Implementation)), "\n",
            "Market V2 Implementation: ", vm.toString(address(marketV2Implementation)), "\n",
            "NFT Proxy (upgraded): ", vm.toString(nftProxyAddress), "\n",
            "Market Proxy (upgraded): ", vm.toString(marketProxyAddress), "\n",
            "Upgrader: ", vm.toString(deployer)
        ));
        
        vm.writeFile("upgrade-v2-info.txt", upgradeInfo);
        console.log("Upgrade info saved to upgrade-v2-info.txt");
        
        console.log("=== Upgrade Complete ===");
        console.log("Both contracts have been successfully upgraded to V2!");
    }
}