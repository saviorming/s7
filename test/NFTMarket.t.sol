pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import {ExtendedERC20} from "src/ExtendedERC20/ExtendedERC20.sol";
import {NFTMarket} from "src/ExtendedERC20/NFTMarket.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// 简单的测试NFT合约
contract TestNFT is ERC721 {
    constructor() ERC721("TestNFT", "TNFT") {}
    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract NFTMarketTest is Test {
    ExtendedERC20 token;
    NFTMarket market;
    TestNFT nft;
    address seller;
    address buyer;

    function setUp() public {
        seller = address(0x1);
        buyer = address(0x2); // 直接用 address(0x2)
        token = new ExtendedERC20();
        market = new NFTMarket(address(token));
        nft = new TestNFT();

        vm.prank(seller);
        nft.mint(seller, 1);

        token.transfer(seller, 1000 ether);
        token.transfer(buyer, 1000 ether);
    }

    function testListAndBuyNFT() public {
        // 卖家授权market操作NFT
        vm.prank(seller);
        nft.approve(address(market), 1);

        // 卖家上架NFT
        vm.prank(seller);
        market.list(address(nft), 1, 100 ether);

        // 验证NFT仍然属于卖家（不转移到合约）
        assertEq(nft.ownerOf(1), seller);

        // 买家授权market划扣token
        vm.prank(buyer);
        token.approve(address(market), 100 ether);

        // 买家购买NFT
        vm.prank(buyer);
        market.buyNFT(0);

        // 验证NFT现在属于买家
        assertEq(nft.ownerOf(1), buyer);
        // 检查token余额
        assertEq(token.balanceOf(seller), 1100 ether);
        assertEq(token.balanceOf(buyer), 900 ether);
    }

    function testBuyNFTWithCallback() public {
        vm.prank(seller);
        nft.approve(address(market), 1);

        vm.prank(seller);
        market.list(address(nft), 1, 100 ether);

        // 验证NFT仍然属于卖家（不转移到合约）
        assertEq(nft.ownerOf(1), seller);

        vm.startPrank(buyer);
        token.transferWithCallback(address(market), 100 ether, abi.encode(uint256(0)));
        vm.stopPrank();

        // 验证NFT现在属于买家
        assertEq(nft.ownerOf(1), buyer);
        assertEq(token.balanceOf(seller), 1100 ether);
        assertEq(token.balanceOf(buyer), 900 ether);
    }

    function testLogBuyerVariable() public {
        console.log("buyer variable:", buyer);
    }
}