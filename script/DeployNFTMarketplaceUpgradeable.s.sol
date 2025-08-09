// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NftMark/Upgrade/NftUpgradeV1.sol";
import "../src/NftMark/Upgrade/NFTMarketplaceV1.sol";
import "../src/ExtendedERC20/ExtendedERC20.sol";

contract DeployNFTMarketplaceUpgradeable is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 ERC20 支付代币
        console.log("Deploying ERC20 Payment Token...");
        ExtendedERC20 paymentToken = new ExtendedERC20();
        console.log("Payment Token deployed at:", address(paymentToken));
        
        // 2. 部署 NFT 实现合约
        console.log("Deploying NFT Implementation...");
        NftUpgradeV1 nftImplementation = new NftUpgradeV1();
        console.log("NFT Implementation deployed at:", address(nftImplementation));
        
        // 3. 部署 NFT 代理合约
        console.log("Deploying NFT Proxy...");
        bytes memory nftInitData = abi.encodeWithSelector(
            NftUpgradeV1.initialize.selector,
            "Upgradeable NFT",
            "UNFT", 
            "https://api.example.com/metadata/",
            deployer
        );
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftImplementation), nftInitData);
        console.log("NFT Proxy deployed at:", address(nftProxy));
        
        // 4. 部署市场实现合约
        console.log("Deploying Market Implementation...");
        NFTMarketplaceV1 marketImplementation = new NFTMarketplaceV1();
        console.log("Market Implementation deployed at:", address(marketImplementation));
        
        // 5. 部署市场代理合约
        console.log("Deploying Market Proxy...");
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketplaceV1.initialize.selector,
            address(paymentToken),
            deployer
        );
        ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketImplementation), marketInitData);
        console.log("Market Proxy deployed at:", address(marketProxy));
        
        vm.stopBroadcast();
        
        // 输出部署信息
        console.log("=== Deployment Complete ===");
        console.log("Payment Token:", address(paymentToken));
        console.log("NFT Implementation:", address(nftImplementation));
        console.log("NFT Proxy:", address(nftProxy));
        console.log("Market Implementation:", address(marketImplementation));
        console.log("Market Proxy:", address(marketProxy));
        console.log("Deployer:", deployer);
        
        // 保存部署信息
        string memory deploymentInfo = string(abi.encodePacked(
            "Payment Token: ", vm.toString(address(paymentToken)), "\n",
            "NFT Implementation: ", vm.toString(address(nftImplementation)), "\n", 
            "NFT Proxy: ", vm.toString(address(nftProxy)), "\n",
            "Market Implementation: ", vm.toString(address(marketImplementation)), "\n",
            "Market Proxy: ", vm.toString(address(marketProxy)), "\n",
            "Deployer: ", vm.toString(deployer)
        ));
        
        vm.writeFile("deployment-info.txt", deploymentInfo);
        console.log("Deployment info saved to deployment-info.txt");
    }
}

// 升级脚本
contract UpgradeToV2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // 从环境变量或配置文件读取已部署的代理合约地址
        address nftProxyAddress = vm.envAddress("NFT_PROXY_ADDRESS");
        address marketProxyAddress = vm.envAddress("MARKET_PROXY_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 部署 V2 实现合约
        console.log("Deploying V2 implementations...");
        
        // 这里需要导入 V2 合约
        // NftUpgradeV2 nftV2Implementation = new NftUpgradeV2();
        // NFTMarketplaceV2 marketV2Implementation = new NFTMarketplaceV2();
        
        // 2. 升级合约
        // NftUpgradeV1 nftProxy = NftUpgradeV1(nftProxyAddress);
        // NFTMarketplaceV1 marketProxy = NFTMarketplaceV1(marketProxyAddress);
        
        // nftProxy.upgradeToAndCall(address(nftV2Implementation), "");
        // marketProxy.upgradeToAndCall(address(marketV2Implementation), "");
        
        // 3. 初始化 V2 功能
        // NftUpgradeV2(nftProxyAddress).upgradeInitialize(true);
        // NFTMarketplaceV2(marketProxyAddress).initializeV2();
        
        vm.stopBroadcast();
        
        console.log("Upgrade to V2 complete!");
    }
}