// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/NftMark/PerMitAndMutilcall/AirdopMerkleNFTMarket.sol";
import "../src/NftMark/PerMitAndMutilcall/Erc20TokenWithPermit.sol";
import "../src/NftMark/BasicVersion/BaseNft.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdopMerkleNFTMarketCompleteTest is Test {
    AirdopMerkleNFTMarket public market;
    Erc20TokenWithPermit public token;
    BaseNft public nft;
    
    address public owner = address(0x1);
    address public admin = address(0x2);
    address public seller = address(0x3);
    address public buyer = address(0x4);
    address public nonWhitelistUser = address(0x5);
    
    // Merkle tree data
    bytes32 public merkleRoot;
    bytes32[] public buyerProof;
    
    // NFT and pricing
    uint256 public tokenId; // 将在setUp中设置
    uint256 public nftPrice = 1000 * 10**18; // 1000 tokens
    uint256 public discountPrice = 500 * 10**18; // 50% discount
    
    // Permit signature data
    uint256 private buyerPrivateKey = 0x123456;
    address private buyerFromPrivateKey;
    
    function setUp() public {
        // 设置买家地址
        buyerFromPrivateKey = vm.addr(buyerPrivateKey);
        buyer = buyerFromPrivateKey;
        
        // 部署合约
        vm.startPrank(owner);
        token = new Erc20TokenWithPermit();
        nft = new BaseNft("TestNFT", "TNFT");
        
        // 创建正确的Merkle树
        setupMerkleTree();
        
        market = new AirdopMerkleNFTMarket(address(token), merkleRoot, admin);
        vm.stopPrank();
        
        // 分发代币
        vm.startPrank(owner);
        token.mint(buyer, 10000 * 10**18);
        token.mint(admin, 10000 * 10**18);
        token.mint(seller, 1000 * 10**18);
        vm.stopPrank();
        
        // 铸造NFT给seller
        vm.startPrank(owner);
        uint256 mintedTokenId = nft.mint(seller);
        assertEq(mintedTokenId, 0); // 第一个token的ID是0
        tokenId = mintedTokenId;
        vm.stopPrank();
        
        // seller授权NFT给市场
        vm.startPrank(seller);
        nft.approve(address(market), tokenId);
        vm.stopPrank();
        
        // admin授权代币给市场
        vm.startPrank(admin);
        token.approve(address(market), type(uint256).max);
        vm.stopPrank();
    }
    
    function setupMerkleTree() internal {
        // 为了简化测试，我们创建一个只包含buyer的单叶子Merkle树
        bytes32 leaf = keccak256(abi.encodePacked(buyer));
        merkleRoot = leaf; // 单个叶子的情况下，root就是leaf本身
        
        // 单叶子情况下，proof为空
        buyerProof = new bytes32[](0);
    }
    
    function testMerkleTreeVerification() public {
        // 测试buyer在白名单中
        bool isValid = market.checkWhiteList(buyer, buyerProof);
        assertTrue(isValid, "Buyer should be in whitelist");
        
        // 测试非白名单用户
        bool isInvalid = market.checkWhiteList(nonWhitelistUser, buyerProof);
        assertFalse(isInvalid, "Non-whitelist user should not be valid");
    }
    
    function testCompleteWorkflow() public {
        // 1. 上架NFT
        vm.startPrank(seller);
        bool listSuccess = market.list(address(nft), tokenId, nftPrice);
        assertTrue(listSuccess, "NFT listing should succeed");
        vm.stopPrank();
        
        // 2. 记录初始余额
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 adminInitialBalance = token.balanceOf(admin);
        
        console.log("Initial balances:");
        console.log("Buyer:", buyerInitialBalance);
        console.log("Seller:", sellerInitialBalance);
        console.log("Admin:", adminInitialBalance);
        
        // 3. 准备permit签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 value = discountPrice; // 只需要授权折扣价格
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                buyer,
                address(market),
                value,
                token.nonces(buyer),
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, hash);
        
        // 4. 执行permitPrePay
        vm.startPrank(buyer);
        market.permitPrePay(buyer, address(market), value, deadline, v, r, s);
        vm.stopPrank();
        
        // 验证permit授权
        assertEq(token.allowance(buyer, address(market)), value, "Permit authorization should be correct");
        
        // 5. 执行claimNFT
        vm.startPrank(buyer);
        bool claimSuccess = market.claimNFT(0, buyerProof);
        assertTrue(claimSuccess, "NFT claim should succeed");
        vm.stopPrank();
        
        // 6. 验证结果
        // NFT所有权转移
        assertEq(nft.ownerOf(tokenId), buyer, "NFT should be transferred to buyer");
        
        // 验证余额变化
        _verifyBalances(buyerInitialBalance, sellerInitialBalance, adminInitialBalance);
        
        // 白名单状态更新
        assertTrue(market.hasUserClaimedWhitelist(buyer), "Buyer should be marked as claimed");
        
        // NFT状态更新
        AirdopMerkleNFTMarket.NFTinfo memory nftInfo = market.getNFTInfo(0);
        assertFalse(nftInfo.isActive, "NFT should be marked as inactive");
    }
    
    function testMulticallWorkflow() public {
        // 1. 上架NFT
        vm.startPrank(seller);
        market.list(address(nft), tokenId, nftPrice);
        vm.stopPrank();
        
        // 2. 准备permit签名
        uint256 deadline = block.timestamp + 1 hours;
        uint256 value = discountPrice;
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                buyer,
                address(market),
                value,
                token.nonces(buyer),
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, hash);
        
        // 3. 准备multicall数据
        bytes[] memory calls = new bytes[](2);
        
        // 第一个调用：permitPrePay
        calls[0] = abi.encodeWithSelector(
            market.permitPrePay.selector,
            buyer,
            address(market),
            value,
            deadline,
            v,
            r,
            s
        );
        
        // 第二个调用：claimNFT
        calls[1] = abi.encodeWithSelector(
            market.claimNFT.selector,
            0,
            buyerProof
        );
        
        // 4. 记录初始余额
        uint256 buyerInitialBalance = token.balanceOf(buyer);
        uint256 sellerInitialBalance = token.balanceOf(seller);
        uint256 adminInitialBalance = token.balanceOf(admin);
        
        // 5. 执行multicall
        vm.startPrank(buyer);
        bytes[] memory results = market.multicall(calls);
        vm.stopPrank();
        
        // 6. 验证multicall执行成功
        assertEq(results.length, 2, "Should have 2 results");
        
        // 7. 验证最终状态
        assertEq(nft.ownerOf(tokenId), buyer, "NFT should be transferred to buyer");
        assertEq(token.balanceOf(buyer), buyerInitialBalance - discountPrice, "Buyer balance should be correct");
        assertEq(token.balanceOf(seller), sellerInitialBalance + nftPrice, "Seller balance should be correct");
        assertEq(token.balanceOf(admin), adminInitialBalance - (nftPrice - discountPrice), "Admin balance should be correct");
        assertTrue(market.hasUserClaimedWhitelist(buyer), "Buyer should be marked as claimed");
        
        console.log("Multicall workflow completed successfully!");
    }
    
    function test_RevertWhen_ClaimTwice() public {
        // 先成功claim一次
        vm.startPrank(seller);
        market.list(address(nft), tokenId, nftPrice);
        vm.stopPrank();
        
        // 第一次claim
        uint256 deadline = block.timestamp + 1 hours;
        uint256 value = discountPrice;
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                buyer,
                address(market),
                value,
                token.nonces(buyer),
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, hash);
        
        vm.startPrank(buyer);
        market.permitPrePay(buyer, address(market), value, deadline, v, r, s);
        market.claimNFT(0, buyerProof);
        vm.stopPrank();
        
        // 第二次claim应该失败
        vm.startPrank(buyer);
        vm.expectRevert("Already claimed whitelist discount");
        market.claimNFT(0, buyerProof);
        vm.stopPrank();
    }
    
    function test_RevertWhen_NonWhitelistUser() public {
        vm.startPrank(seller);
        market.list(address(nft), tokenId, nftPrice);
        vm.stopPrank();
        
        vm.startPrank(nonWhitelistUser);
        vm.expectRevert("Not in whitelist");
        market.claimNFT(0, buyerProof);
        vm.stopPrank();
    }
    
    function test_RevertWhen_InsufficientAdminBalance() public {
        // 清空admin余额
        vm.startPrank(admin);
        token.transfer(owner, token.balanceOf(admin));
        vm.stopPrank();
        
        vm.startPrank(seller);
        market.list(address(nft), tokenId, nftPrice);
        vm.stopPrank();
        
        uint256 deadline = block.timestamp + 1 hours;
        uint256 value = discountPrice;
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                buyer,
                address(market),
                value,
                token.nonces(buyer),
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, hash);
        
        vm.startPrank(buyer);
        market.permitPrePay(buyer, address(market), value, deadline, v, r, s);
        vm.expectRevert("Admin insufficient balance for discount");
        market.claimNFT(0, buyerProof);
        vm.stopPrank();
    }
    
    function test_RevertWhen_ClaimWithoutPermit() public {
        vm.startPrank(seller);
        market.list(address(nft), tokenId, nftPrice);
        vm.stopPrank();
        
        vm.startPrank(buyer);
        vm.expectRevert("No permit authorization found");
        market.claimNFT(0, buyerProof);
        vm.stopPrank();
    }
    
    function testAdminFunctions() public {
        bytes32 newMerkleRoot = keccak256("new root");
        address newAdmin = address(0x9);
        
        vm.startPrank(owner);
        market.setMerkleRoot(newMerkleRoot);
        market.setAdmin(newAdmin);
        vm.stopPrank();
        
        assertEq(market.merkleRoot(), newMerkleRoot, "Merkle root should be updated");
        assertEq(market.admin(), newAdmin, "Admin should be updated");
    }
    
    function test_RevertWhen_NonOwnerSetAdmin() public {
        vm.startPrank(buyer);
        vm.expectRevert();
        market.setAdmin(address(0x9));
        vm.stopPrank();
    }
    
    function testQueryFunctions() public {
        assertFalse(market.hasUserClaimedWhitelist(buyer), "Buyer should not have claimed initially");
        
        AirdopMerkleNFTMarket.PermitData memory permitData = market.getUserPermitData(buyer);
        assertEq(permitData.owner, address(0), "Should have empty permit data initially");
    }
    
    function testEventEmission() public {
        vm.startPrank(seller);
        market.list(address(nft), tokenId, nftPrice);
        vm.stopPrank();
        
        uint256 deadline = block.timestamp + 1 hours;
        uint256 value = discountPrice;
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                buyer,
                address(market),
                value,
                token.nonces(buyer),
                deadline
            )
        );
        
        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerPrivateKey, hash);
        
        vm.startPrank(buyer);
        
        // 测试PermitPrePaid事件
        vm.expectEmit(true, true, false, true);
        emit AirdopMerkleNFTMarket.PermitPrePaid(buyer, address(market), value);
        market.permitPrePay(buyer, address(market), value, deadline, v, r, s);
        
        // 测试WhitelistClaimed事件
        vm.expectEmit(true, true, false, true);
        emit AirdopMerkleNFTMarket.WhitelistClaimed(buyer, 0, discountPrice, nftPrice - discountPrice);
        market.claimNFT(0, buyerProof);
        
        vm.stopPrank();
    }
    
    // 辅助函数：验证余额变化
    function _verifyBalances(uint256 buyerInitial, uint256 sellerInitial, uint256 adminInitial) internal {
        uint256 buyerFinal = token.balanceOf(buyer);
        uint256 sellerFinal = token.balanceOf(seller);
        uint256 adminFinal = token.balanceOf(admin);
        
        console.log("Final balances:");
        console.log("Buyer:", buyerFinal);
        console.log("Seller:", sellerFinal);
        console.log("Admin:", adminFinal);
        
        // 买家支付了折扣价格
        assertEq(buyerFinal, buyerInitial - discountPrice, "Buyer should pay discount price");
        
        // 卖家收到了全价
        assertEq(sellerFinal, sellerInitial + nftPrice, "Seller should receive full price");
        
        // admin支付了差价
        uint256 adminPayment = nftPrice - discountPrice;
        assertEq(adminFinal, adminInitial - adminPayment, "Admin should pay the difference");
    }
    
}