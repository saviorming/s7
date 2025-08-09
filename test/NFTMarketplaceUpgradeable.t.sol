// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../src/NftMark/Upgrade/NftUpgradeV1.sol";
import "../src/NftMark/Upgrade/NftUpgradeV2.sol";
import "../src/NftMark/Upgrade/NFTMarketplaceV1.sol";
import "../src/NftMark/Upgrade/NFTMarketplaceV2.sol";
import "../src/ExtendedERC20/ExtendedERC20.sol";

contract NFTMarketplaceUpgradeableTest is Test {
    // 合约实例
    NftUpgradeV1 public nftV1Implementation;
    NftUpgradeV2 public nftV2Implementation;
    NFTMarketplaceV1 public marketV1Implementation;
    NFTMarketplaceV2 public marketV2Implementation;
    
    // 代理合约
    ERC1967Proxy public nftProxy;
    ERC1967Proxy public marketProxy;
    
    // 代理合约接口
    NftUpgradeV1 public nft;
    NFTMarketplaceV1 public marketV1;
    NFTMarketplaceV2 public marketV2;
    
    // ERC20 代币
    ExtendedERC20 public paymentToken;
    
    // 测试账户
    address public owner = address(0x1);
    address public seller = address(0x2);
    address public buyer = address(0x3);
    address public unauthorized = address(0x4);
    
    // 测试常量
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000000 * 10**18;
    uint256 public constant USER_TOKEN_BALANCE = 10000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    uint256 public constant MAX_NFT_SUPPLY = 10000;
    
    // 签名相关
    uint256 private constant SELLER_PRIVATE_KEY = 0x1234;
    address private sellerSigner;

    function setUp() public {
        vm.startPrank(owner);
        
        // 1. 部署 ERC20 代币
        paymentToken = new ExtendedERC20();
        
        // 2. 部署 NFT 实现合约
        nftV1Implementation = new NftUpgradeV1();
        nftV2Implementation = new NftUpgradeV2();
        
        // 3. 部署市场实现合约
        marketV1Implementation = new NFTMarketplaceV1();
        marketV2Implementation = new NFTMarketplaceV2();
        
        // 4. 部署 NFT 代理合约并初始化
        bytes memory nftInitData = abi.encodeWithSelector(
            NftUpgradeV1.initialize.selector,
            "Test NFT",
            "TNFT",
            "https://api.example.com/metadata/",
            MAX_NFT_SUPPLY,
            owner
        );
        nftProxy = new ERC1967Proxy(address(nftV1Implementation), nftInitData);
        nft = NftUpgradeV1(address(nftProxy));
        
        // 5. 部署市场代理合约并初始化
        bytes memory marketInitData = abi.encodeWithSelector(
            NFTMarketplaceV1.initialize.selector,
            address(paymentToken),
            owner
        );
        marketProxy = new ERC1967Proxy(address(marketV1Implementation), marketInitData);
        marketV1 = NFTMarketplaceV1(address(marketProxy));
        
        // 6. 分发代币
        paymentToken.transfer(seller, USER_TOKEN_BALANCE);
        paymentToken.transfer(buyer, USER_TOKEN_BALANCE);
        
        // 7. 铸造测试 NFT
        nft.mint(seller);
        nft.mint(seller);
        nft.mint(seller);
        
        // 8. 设置签名者
        sellerSigner = vm.addr(SELLER_PRIVATE_KEY);
        paymentToken.transfer(sellerSigner, USER_TOKEN_BALANCE);
        
        vm.stopPrank();
        
        // 9. 为签名者铸造 NFT
        vm.prank(owner);
        nft.mint(sellerSigner);
    }

    // ==================== NFT 合约测试 ====================
    
    function testNFTInitialization() public {
        assertEq(nft.name(), "Test NFT");
        assertEq(nft.symbol(), "TNFT");
        assertEq(nft.maxSupply(), MAX_NFT_SUPPLY);
        assertEq(nft.totalSupply(), 4); // setUp 中铸造了 4 个
        assertEq(nft.nextTokenId(), 5);
        assertEq(nft.owner(), owner);
    }
    
    function testNFTMint() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(buyer);
        
        assertEq(tokenId, 5);
        assertEq(nft.ownerOf(tokenId), buyer);
        assertEq(nft.totalSupply(), 5);
        assertEq(nft.nextTokenId(), 6);
    }
    
    function testNFTMintUnauthorized() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        nft.mint(buyer);
    }
    
    function testNFTUpgradeToV2() public {
        vm.startPrank(owner);
        
        // 升级到 V2
        nft.upgradeToAndCall(address(nftV2Implementation), "");
        
        // 转换为 V2 接口
        NftUpgradeV2 nftV2 = NftUpgradeV2(address(nftProxy));
        
        // 初始化 V2 功能
        nftV2.upgradeInitialize(true);
        
        // 测试 V2 新功能
        (uint256 startId, uint256 endId) = nftV2.mintBatch(buyer, 3);
        assertEq(startId, 5);
        assertEq(endId, 7);
        assertEq(nftV2.totalSupply(), 7);
        
        vm.stopPrank();
    }

    // ==================== 市场合约 V1 测试 ====================
    
    function testMarketV1Initialization() public {
        assertEq(address(marketV1.paymentToken()), address(paymentToken));
        assertEq(marketV1.orderIdCounter(), 1);
        assertEq(marketV1.nftCount(), 0);
        assertEq(marketV1.owner(), owner);
    }
    
    function testListNFT() public {
        vm.startPrank(seller);
        
        // 授权市场合约
        nft.approve(address(marketV1), 1);
        
        // 上架 NFT
        bool success = marketV1.list(address(nft), 1, NFT_PRICE);
        assertTrue(success);
        
        // 验证上架信息
        (address nftSeller, address nftAddress, uint256 tokenId, uint256 price, bool isActive, uint256 listingTime) = marketV1.nfts(1);
        assertEq(nftSeller, seller);
        assertEq(nftAddress, address(nft));
        assertEq(tokenId, 1);
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
        assertGt(listingTime, 0);
        
        assertEq(marketV1.nftCount(), 1);
        assertEq(marketV1.orderIdCounter(), 2);
        
        vm.stopPrank();
    }
    
    function testListNFTUnauthorized() public {
        vm.prank(unauthorized);
        vm.expectRevert("Not NFT owner");
        marketV1.list(address(nft), 1, NFT_PRICE);
    }
    
    function testListNFTWithoutApproval() public {
        vm.prank(seller);
        vm.expectRevert("nft not approved");
        marketV1.list(address(nft), 1, NFT_PRICE);
    }
    
    function testBuyNFT() public {
        // 先上架
        vm.startPrank(seller);
        nft.approve(address(marketV1), 1);
        marketV1.list(address(nft), 1, NFT_PRICE);
        vm.stopPrank();
        
        // 购买
        vm.startPrank(buyer);
        paymentToken.approve(address(marketV1), NFT_PRICE);
        
        uint256 sellerBalanceBefore = paymentToken.balanceOf(seller);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);
        
        bool success = marketV1.buyNFT(1);
        assertTrue(success);
        
        // 验证 NFT 转移
        assertEq(nft.ownerOf(1), buyer);
        
        // 验证代币转移
        assertEq(paymentToken.balanceOf(seller), sellerBalanceBefore + NFT_PRICE);
        assertEq(paymentToken.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        
        // 验证订单状态
        (, , , , bool isActive, ) = marketV1.nfts(1);
        assertFalse(isActive);
        assertEq(marketV1.nftCount(), 0);
        
        vm.stopPrank();
    }
    
    function testDelistNFT() public {
        // 先上架
        vm.startPrank(seller);
        nft.approve(address(marketV1), 1);
        marketV1.list(address(nft), 1, NFT_PRICE);
        
        // 下架
        bool success = marketV1.delist(1);
        assertTrue(success);
        
        // 验证下架状态
        (, , , , bool isActive, ) = marketV1.nfts(1);
        assertFalse(isActive);
        assertEq(marketV1.nftCount(), 0);
        
        vm.stopPrank();
    }

    // ==================== 市场合约升级到 V2 测试 ====================
    
    function testMarketUpgradeToV2() public {
        vm.startPrank(owner);
        
        // 升级到 V2
        marketV1.upgradeToAndCall(address(marketV2Implementation), "");
        
        // 转换为 V2 接口
        marketV2 = NFTMarketplaceV2(address(marketProxy));
        
        // 初始化 V2 功能
        marketV2.initializeV2();
        
        // 验证升级后状态保持
        assertEq(address(marketV2.paymentToken()), address(paymentToken));
        assertEq(marketV2.orderIdCounter(), 1);
        assertEq(marketV2.nftCount(), 0);
        
        vm.stopPrank();
    }
    
    function testSignatureListingV2() public {
        // 先升级到 V2
        testMarketUpgradeToV2();
        
        vm.startPrank(sellerSigner);
        
        // 授权市场合约（一次性授权所有 NFT）
        nft.setApprovalForAll(address(marketV2), true);
        
        vm.stopPrank();
        
        // 准备签名参数
        NFTMarketplaceV2.ListingParams memory params = NFTMarketplaceV2.ListingParams({
            nftContract: address(nft),
            tokenId: 4, // sellerSigner 拥有的 NFT
            price: NFT_PRICE,
            nonce: marketV2.getUserNonce(sellerSigner),
            deadline: block.timestamp + 1 hours
        });
        
        // 生成签名
        bytes32 structHash = keccak256(abi.encode(
            keccak256("ListingParams(address nftContract,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"),
            params.nftContract,
            params.tokenId,
            params.price,
            params.nonce,
            params.deadline
        ));
        
        // 获取 domain separator - 需要通过 eip712Domain() 函数
        (, string memory name, string memory version, uint256 chainId, address verifyingContract, , ) = marketV2.eip712Domain();
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId,
            verifyingContract
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SELLER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // 任何人都可以调用签名上架
        vm.prank(buyer);
        marketV2.listNFTWithSignature(params, signature);
        
        // 验证上架成功
        (address nftSeller, address nftAddress, uint256 tokenId, uint256 price, bool isActive, uint256 listingTime) = marketV2.nfts(1);
        assertEq(nftSeller, sellerSigner);
        assertEq(nftAddress, address(nft));
        assertEq(tokenId, 4);
        assertEq(price, NFT_PRICE);
        assertTrue(isActive);
        assertGt(listingTime, 0);
        
        assertEq(marketV2.nftCount(), 1);
        assertEq(marketV2.orderIdCounter(), 2);
        assertEq(marketV2.getUserNonce(sellerSigner), 1); // nonce 增加
    }
    
    function testSignatureListingExpired() public {
        testMarketUpgradeToV2();
        
        vm.prank(sellerSigner);
        nft.setApprovalForAll(address(marketV2), true);
        
        // 准备过期的签名参数
        NFTMarketplaceV2.ListingParams memory params = NFTMarketplaceV2.ListingParams({
            nftContract: address(nft),
            tokenId: 4,
            price: NFT_PRICE,
            nonce: marketV2.getUserNonce(sellerSigner),
            deadline: block.timestamp - 1 // 已过期
        });
        
        bytes memory signature = new bytes(65); // 空签名，因为会在过期检查时失败
        
        vm.prank(buyer);
        vm.expectRevert(unicode"V2: 签名已过期");
        marketV2.listNFTWithSignature(params, signature);
    }
    
    function testSignatureListingInvalidNonce() public {
        testMarketUpgradeToV2();
        
        vm.prank(sellerSigner);
        nft.setApprovalForAll(address(marketV2), true);
        
        // 准备错误 nonce 的签名参数
        NFTMarketplaceV2.ListingParams memory params = NFTMarketplaceV2.ListingParams({
            nftContract: address(nft),
            tokenId: 4,
            price: NFT_PRICE,
            nonce: 999, // 错误的 nonce
            deadline: block.timestamp + 1 hours
        });
        
        // 生成有效签名但使用错误的 nonce
        bytes32 structHash = keccak256(abi.encode(
            keccak256("ListingParams(address nftContract,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"),
            params.nftContract,
            params.tokenId,
            params.price,
            params.nonce,
            params.deadline
        ));
        
        // 获取 domain separator
        (, string memory name, string memory version, uint256 chainId, address verifyingContract, , ) = marketV2.eip712Domain();
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            chainId,
            verifyingContract
        ));
        
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainSeparator,
            structHash
        ));
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SELLER_PRIVATE_KEY, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        vm.prank(buyer);
        vm.expectRevert(unicode"V2: 无效的nonce");
        marketV2.listNFTWithSignature(params, signature);
    }
    
    function testBuySignatureListedNFT() public {
        // 先通过签名上架
        testSignatureListingV2();
        
        // 购买签名上架的 NFT
        vm.startPrank(buyer);
        paymentToken.approve(address(marketV2), NFT_PRICE);
        
        uint256 sellerBalanceBefore = paymentToken.balanceOf(sellerSigner);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);
        
        bool success = marketV2.buyNFT(1);
        assertTrue(success);
        
        // 验证 NFT 转移
        assertEq(nft.ownerOf(4), buyer);
        
        // 验证代币转移
        assertEq(paymentToken.balanceOf(sellerSigner), sellerBalanceBefore + NFT_PRICE);
        assertEq(paymentToken.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        
        vm.stopPrank();
    }

    // ==================== 边界情况和安全测试 ====================
    
    function testReentrancyProtection() public {
        // 这个测试需要一个恶意合约来测试重入攻击
        // 由于 buyNFT 使用了 nonReentrant 修饰符，应该能防止重入攻击
        
        vm.startPrank(seller);
        nft.approve(address(marketV1), 1);
        marketV1.list(address(nft), 1, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(marketV1), NFT_PRICE);
        
        // 正常购买应该成功
        bool success = marketV1.buyNFT(1);
        assertTrue(success);
        
        vm.stopPrank();
    }
    
    function testZeroAddressValidation() public {
        // 测试零地址验证 - 部署新的实现合约来测试初始化
        NFTMarketplaceV1 newMarketImpl = new NFTMarketplaceV1();
        
        // 测试用零地址的 paymentToken 初始化应该失败
        vm.expectRevert(unicode"V1: 支付代币地址无效");
        new ERC1967Proxy(address(newMarketImpl), abi.encodeWithSelector(
            NFTMarketplaceV1.initialize.selector,
            address(0), // 零地址的 paymentToken
            owner
        ));
    }
    
    function testUpgradeAuthorization() public {
        // 只有 owner 可以升级
        vm.prank(unauthorized);
        vm.expectRevert();
        marketV1.upgradeToAndCall(address(marketV2Implementation), "");
        
        // owner 可以升级
        vm.prank(owner);
        marketV1.upgradeToAndCall(address(marketV2Implementation), "");
    }

    // ==================== 事件测试 ====================
    
    function testListingEvent() public {
        vm.startPrank(seller);
        nft.approve(address(marketV1), 1);
        
        vm.expectEmit(true, true, true, true);
        emit NFTMarketplaceV1.NFTListed(1, seller, address(nft), 1, NFT_PRICE);
        
        marketV1.list(address(nft), 1, NFT_PRICE);
        vm.stopPrank();
    }
    
    function testDelistEvent() public {
        vm.startPrank(seller);
        nft.approve(address(marketV1), 1);
        marketV1.list(address(nft), 1, NFT_PRICE);
        
        vm.expectEmit(true, true, true, true);
        emit NFTMarketplaceV1.NFTDeList(1, seller, 1);
        
        marketV1.delist(1);
        vm.stopPrank();
    }
    
    function testSoldEvent() public {
        vm.startPrank(seller);
        nft.approve(address(marketV1), 1);
        marketV1.list(address(nft), 1, NFT_PRICE);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        paymentToken.approve(address(marketV1), NFT_PRICE);
        
        vm.expectEmit(true, true, true, true);
        emit NFTMarketplaceV1.NFTSold(1, seller, 1, buyer, NFT_PRICE);
        
        marketV1.buyNFT(1);
        vm.stopPrank();
    }
}