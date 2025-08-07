// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/NftMark/BasicVersion/NFTMarket.sol";
import "../src/NftMark/BasicVersion/BaseErc20Token.sol";
import "../src/NftMark/BasicVersion/BaseNft.sol";

contract NFTMarketTest is Test {
    NFTMarket public market;
    BaseErc20Token public token;
    BaseNft public nft;
    
    address public owner;
    address public seller;
    address public buyer;
    address public buyer2;
    
    uint256 public constant INITIAL_BALANCE = 1000 * 10**18;
    uint256 public constant NFT_PRICE = 100 * 10**18;
    
    function setUp() public {
        owner = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");
        buyer2 = makeAddr("buyer2");
        
        // 部署合约
        token = new BaseErc20Token();
        nft = new BaseNft("TestNFT", "TNFT");
        market = new NFTMarket(address(token));
        
        // 给用户分配代币
        token.mint(seller, INITIAL_BALANCE);
        token.mint(buyer, INITIAL_BALANCE);
        token.mint(buyer2, INITIAL_BALANCE);
        
        // 给seller铸造NFT
        vm.startPrank(owner);
        nft.mint(seller);
        nft.mint(seller);
        nft.mint(seller);
        vm.stopPrank();
    }
    
    function testListNFT() public {
        vm.startPrank(seller);
        
        // 授权NFT给市场合约
        nft.approve(address(market), 0);
        
        // 上架NFT
        bool success = market.list(address(nft), 0, NFT_PRICE);
        assertTrue(success);
        
        // 验证上架信息
        NFTMarket.NFTinfo memory nftInfo = market.getNFTInfo(0);
        assertEq(nftInfo.seller, seller);
        assertEq(nftInfo.nftAddress, address(nft));
        assertEq(nftInfo.tokenId, 0);
        assertEq(nftInfo.price, NFT_PRICE);
        assertTrue(nftInfo.isActive);
        
        // 验证计数器
        assertEq(market.nftCount(), 1);
        assertEq(market.getCurrentMarketId(), 1);
        
        vm.stopPrank();
    }
    
    function testListNFTFailures() public {
        vm.startPrank(buyer); // 不是NFT拥有者
        
        // 应该失败：不是NFT拥有者
        vm.expectRevert("Not NFT owner");
        market.list(address(nft), 0, NFT_PRICE);
        
        vm.stopPrank();
        vm.startPrank(seller);
        
        // 应该失败：价格为0
        vm.expectRevert("price is zero");
        market.list(address(nft), 0, 0);
        
        // 应该失败：未授权
        vm.expectRevert("nft not approved");
        market.list(address(nft), 0, NFT_PRICE);
        
        vm.stopPrank();
    }
    
    function testBuyNFT() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        // 买家购买NFT
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        
        bool success = market.buyNFT(0);
        assertTrue(success);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(0), buyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), sellerBalanceBefore + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        
        // 验证NFT状态更新
        NFTMarket.NFTinfo memory nftInfo = market.getNFTInfo(0);
        assertFalse(nftInfo.isActive);
        assertEq(market.nftCount(), 0);
        
        vm.stopPrank();
    }
    
    function testBuyNFTFailures() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        // 应该失败：卖家不能购买自己的NFT
        vm.startPrank(seller);
        token.approve(address(market), NFT_PRICE);
        vm.expectRevert("Cannot buy your own NFT");
        market.buyNFT(0);
        vm.stopPrank();
        
        // 应该失败：余额不足
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        // 转走大部分代币
        token.transfer(seller, INITIAL_BALANCE - NFT_PRICE + 1);
        vm.expectRevert("token not enough");
        market.buyNFT(0);
        vm.stopPrank();
    }
    
    function testDelist() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(address(nft), 0, NFT_PRICE);
        
        // 下架NFT
        bool success = market.delist(0);
        assertTrue(success);
        
        // 验证NFT状态
        NFTMarket.NFTinfo memory nftInfo = market.getNFTInfo(0);
        assertFalse(nftInfo.isActive);
        assertEq(market.nftCount(), 0);
        
        vm.stopPrank();
    }
    
    function testDelistFailures() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        // 应该失败：只有卖家可以下架
        vm.startPrank(buyer);
        vm.expectRevert("only seller can delist");
        market.delist(0);
        vm.stopPrank();
        
        // 下架后再次下架应该失败
        vm.startPrank(seller);
        market.delist(0);
        vm.expectRevert("nft not active");
        market.delist(0);
        vm.stopPrank();
    }
    
    function testTokensReceivedCallback() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        // 使用回调方式购买
        vm.startPrank(buyer);
        
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        
        // 编码购买的NFT ID
        bytes memory data = abi.encode(uint256(0));
        
        // 使用transferWithCallback触发购买
        token.transferWithCallback(address(market), NFT_PRICE, data);
        
        // 验证NFT所有权转移
        assertEq(nft.ownerOf(0), buyer);
        
        // 验证代币转移
        assertEq(token.balanceOf(seller), sellerBalanceBefore + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        
        // 验证NFT状态更新
        NFTMarket.NFTinfo memory nftInfo = market.getNFTInfo(0);
        assertFalse(nftInfo.isActive);
        
        vm.stopPrank();
    }
    
    function testTokensReceivedWithRefund() public {
        // 先上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        // 使用超额支付测试退款
        vm.startPrank(buyer);
        
        uint256 overpayAmount = NFT_PRICE + 50 * 10**18;
        uint256 sellerBalanceBefore = token.balanceOf(seller);
        uint256 buyerBalanceBefore = token.balanceOf(buyer);
        
        bytes memory data = abi.encode(uint256(0));
        token.transferWithCallback(address(market), overpayAmount, data);
        
        // 验证正确的代币转移（买家应该收到退款）
        assertEq(token.balanceOf(seller), sellerBalanceBefore + NFT_PRICE);
        assertEq(token.balanceOf(buyer), buyerBalanceBefore - NFT_PRICE);
        
        vm.stopPrank();
    }
    
    function testGetActiveListings() public {
        vm.startPrank(seller);
        
        // 上架多个NFT
        nft.approve(address(market), 0);
        nft.approve(address(market), 1);
        nft.approve(address(market), 2);
        
        market.list(address(nft), 0, NFT_PRICE);
        market.list(address(nft), 1, NFT_PRICE * 2);
        market.list(address(nft), 2, NFT_PRICE * 3);
        
        // 获取活跃列表
        uint256[] memory activeListings = market.getActiveListings();
        assertEq(activeListings.length, 3);
        assertEq(activeListings[0], 0);
        assertEq(activeListings[1], 1);
        assertEq(activeListings[2], 2);
        
        // 下架一个NFT
        market.delist(1);
        
        // 再次获取活跃列表
        activeListings = market.getActiveListings();
        assertEq(activeListings.length, 2);
        assertEq(activeListings[0], 0);
        assertEq(activeListings[1], 2);
        
        vm.stopPrank();
    }
    
    function testGetUserListings() public {
        vm.startPrank(seller);
        
        // 上架多个NFT
        nft.approve(address(market), 0);
        nft.approve(address(market), 1);
        
        market.list(address(nft), 0, NFT_PRICE);
        market.list(address(nft), 1, NFT_PRICE * 2);
        
        // 获取用户列表
        uint256[] memory userListings = market.getUserListings(seller);
        assertEq(userListings.length, 2);
        assertEq(userListings[0], 0);
        assertEq(userListings[1], 1);
        
        vm.stopPrank();
    }
    
    function testMultipleBuyersCompetition() public {
        // 上架NFT
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        market.list(address(nft), 0, NFT_PRICE);
        vm.stopPrank();
        
        // 第一个买家购买
        vm.startPrank(buyer);
        token.approve(address(market), NFT_PRICE);
        market.buyNFT(0);
        vm.stopPrank();
        
        // 第二个买家尝试购买同一个NFT应该失败
        vm.startPrank(buyer2);
        token.approve(address(market), NFT_PRICE);
        vm.expectRevert("nft not active");
        market.buyNFT(0);
        vm.stopPrank();
    }
    
    function testEventEmission() public {
        vm.startPrank(seller);
        nft.approve(address(market), 0);
        
        // 测试上架事件
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.NFTListed(0, seller, address(nft), 0, NFT_PRICE);
        market.list(address(nft), 0, NFT_PRICE);
        
        // 测试下架事件
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.NFTDeList(0, seller, 0);
        market.delist(0);
        
        vm.stopPrank();
    }
}