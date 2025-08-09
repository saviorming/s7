// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NftMark/Upgrade/NftUpgradeV1.sol";
import "../src/NftMark/Upgrade/NFTMarketplaceV1.sol";
import "../src/ExtendedERC20/ExtendedERC20.sol";

/**
 * @title DeployToSepolia
 * @dev Sepolia testnet deployment script
 */
contract DeployToSepolia is Script {
    // Deploy configuration
    struct DeployConfig {
        string nftName;
        string nftSymbol;
        string baseURI;
        address deployer;
    }

    // Deploy result
    struct DeployResult {
        address paymentToken;
        address nftImplementation;
        address marketImplementation;
        address nftProxy;
        address marketProxy;
        address proxyAdmin;
    }

    function run() external {
        // Get deployer private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Sepolia Deploy Start ===");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");
        
        // Check balance
        require(deployer.balance >= 0.1 ether, "Insufficient balance, need at least 0.1 ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy configuration
        DeployConfig memory config = DeployConfig({
            nftName: vm.envString("NFT_NAME"),
            nftSymbol: vm.envString("NFT_SYMBOL"),
            baseURI: vm.envString("NFT_BASE_URI"),
            deployer: deployer
        });

        // Execute deployment
        DeployResult memory result = deployContracts(config);

        vm.stopBroadcast();

        // Save deployment info
        saveDeploymentInfo(result);
        
        // Output deployment result
        logDeploymentResult(result);
        
        console.log("=== Sepolia Deploy Complete ===");
    }

    function deployContracts(DeployConfig memory config) internal returns (DeployResult memory) {
        DeployResult memory result;

        console.log("\\n1. Deploying payment token...");
        result.paymentToken = address(new ExtendedERC20());
        console.log("ExtendedERC20 address:", result.paymentToken);

        console.log("\\n2. Deploying NFT implementation...");
        result.nftImplementation = address(new NftUpgradeV1());
        console.log("NFT implementation address:", result.nftImplementation);

        console.log("\\n3. Deploying marketplace implementation...");
        result.marketImplementation = address(new NFTMarketplaceV1());
        console.log("Marketplace implementation address:", result.marketImplementation);

        console.log("\\n4. Deploying NFT proxy...");
        bytes memory nftInitData = abi.encodeWithSelector(
            NftUpgradeV1.initialize.selector,
            config.nftName,
            config.nftSymbol,
            config.baseURI,
            config.deployer
        );
        result.nftProxy = address(new ERC1967Proxy(result.nftImplementation, nftInitData));
        console.log("NFT proxy address:", result.nftProxy);

        console.log("\\n5. Deploying marketplace proxy...");
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketplaceV1.initialize.selector,
            result.paymentToken,
            config.deployer
        );
        result.marketProxy = address(new ERC1967Proxy(result.marketImplementation, marketInitData));
        console.log("Marketplace proxy address:", result.marketProxy);

        // Get proxy admin address
        result.proxyAdmin = config.deployer; // In UUPS mode, proxy admin is the contract itself

        return result;
    }

    function saveDeploymentInfo(DeployResult memory result) internal {
        string memory deploymentInfo = string(abi.encodePacked(
            "# Sepolia Testnet Deployment Info\\n\\n",
            "## Contract Addresses\\n",
            "- ExtendedERC20: ", vm.toString(result.paymentToken), "\\n",
            "- NFT Implementation: ", vm.toString(result.nftImplementation), "\\n",
            "- Marketplace Implementation: ", vm.toString(result.marketImplementation), "\\n",
            "- NFT Proxy: ", vm.toString(result.nftProxy), "\\n",
            "- Marketplace Proxy: ", vm.toString(result.marketProxy), "\\n",
            "- Proxy Admin: ", vm.toString(result.proxyAdmin), "\\n\\n"
        ));

        vm.writeFile("sepolia-deployment.md", deploymentInfo);
        console.log("\\nDeployment info saved to sepolia-deployment.md");
    }

    function logDeploymentResult(DeployResult memory result) internal view {
        console.log("\\n=== Deployment Summary ===");
        console.log("ExtendedERC20:", result.paymentToken);
        console.log("NFT Implementation:", result.nftImplementation);
        console.log("Marketplace Implementation:", result.marketImplementation);
        console.log("NFT Proxy:", result.nftProxy);
        console.log("Marketplace Proxy:", result.marketProxy);
        console.log("Proxy Admin:", result.proxyAdmin);
        
        console.log("\\n=== Etherscan Links ===");
        console.log("ExtendedERC20: https://sepolia.etherscan.io/address/", result.paymentToken);
        console.log("NFT Proxy: https://sepolia.etherscan.io/address/", result.nftProxy);
        console.log("Marketplace Proxy: https://sepolia.etherscan.io/address/", result.marketProxy);
    }
}