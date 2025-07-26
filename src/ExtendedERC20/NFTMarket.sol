pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20Callback,ExtendedERC20} from "../ExtendedERC20/ExtendedERC20.sol";
import "forge-std/console.sol";


contract NFTMarket is IERC20Callback{
    //使用ExtendedERC20支持的token,
    ExtendedERC20 public payToken;
    //上架结构体
    struct Listing{
        //持有人
        address seller;
        //NFT合约地址
        address nftAddress;
        //NFT tokenId
        uint256 tokenId;
        //NFT价格
        uint256 price;
        //是否上架标识 true：上架 false：下架
        bool isActive;
        //上架时间
        uint256 listingTime;
    }
    // 存储已生效的nft，用于展示
    uint256[] public listingIds;
    //存储已上架的NFT
    mapping(uint256 => Listing) public nfts;
    // 自增id，每次上架一个nft就自增一次，用来做定位
    uint256 public listingId;
    //上架列表
    constructor(address _tokenAddress){
        payToken = ExtendedERC20(_tokenAddress);
    }

    event NFTList(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTBuy(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    //event NFTListingCancelled(uint256 indexed listingId);

    function list(address nftAddress,uint256 tokenId,uint256 price) external{
        //只能支持nft
        IERC721 nft = IERC721(nftAddress);
        //验证授权以及是否是持有人
        require(nft.ownerOf(tokenId) == msg.sender, "Not NFT owner");
        require(
            nft.getApproved(tokenId) == address(this) ||
            nft.isApprovedForAll(msg.sender, address(this)),
            "Market not approved"
        );
        require(price > 0,"Price must be greater than 0");
        
        //上架到市场中（NFT仍保留在卖家手中）
        nfts[listingId] = Listing(msg.sender, nftAddress, tokenId,price,true,block.timestamp);
        //增加到列表中,后续用于展示
        listingIds.push(listingId);
        //调用事件
        emit NFTList(listingId, msg.sender, nftAddress, tokenId, price);
        //自增id，用于后续
        listingId++;
    }

    function buyNFT(uint256 _listingId) external{
        //验证对应的nft是否存在
        Listing storage nftInfo = nfts[_listingId];
        require(nftInfo.isActive, "NFT is not active");
        require(nftInfo.seller != msg.sender, "Cannot buy your own NFT");
        //验证购买用户余额是否足够
        require(payToken.balanceOf(msg.sender) >= nftInfo.price, "Insufficient balance");
        
        uint256 price = nftInfo.price;
        address seller = nftInfo.seller;
        
        //标记为已售出
        nftInfo.isActive = false;
        
        //进行token转账给卖家
        bool success = payToken.transferFrom(msg.sender, seller, price);
        require(success, "Token transfer failed");
        
        //从卖家转移NFT给购买者
        IERC721(nftInfo.nftAddress).safeTransferFrom(seller, msg.sender, nftInfo.tokenId);
        
        //调用事件
        emit NFTBuy(_listingId, msg.sender, seller, nftInfo.nftAddress, nftInfo.tokenId, price);
    } 

    //回调,用于用户直接向市场进行了转账，并指定了对应的nft的listingId
    function tokensReceived(address sender, uint256 amount, bytes memory data) external override{
        //验证调用者是否是指定的token
        require(msg.sender == address(payToken), "Only token contract can call");
        uint256 buyListingId = abi.decode(data,(uint256));
        Listing storage nftInfo = nfts[buyListingId];
        //验证是否存在且是上架状态
        require(nftInfo.isActive,"can't find the nft");
        require(nftInfo.seller != sender, "Cannot buy your own NFT");
        require(amount >= nftInfo.price,"price not enough");
        
        address seller = nftInfo.seller;
        uint256 price = nftInfo.price;
        
        //如果钱超出nft的价格，后续需要将超出的部分返还
        if(amount > price){
            //转账超出的金额给sender（买家）
            require(payToken.transfer(sender, amount - price), "Refund failed");
        }
        
        //转账给卖家
        require(payToken.transfer(seller, price), "Payment to seller failed");
        
        //nft下架
        nftInfo.isActive = false;
        
        //从卖家转移NFT给购买者
        IERC721(nftInfo.nftAddress).safeTransferFrom(seller, sender, nftInfo.tokenId);
        
        emit NFTBuy(buyListingId, sender, seller, nftInfo.nftAddress, nftInfo.tokenId, price);
        console.log("tokensReceived sender:", sender);
    }
    
    // 下架功能
    function delist(uint256 _listingId) external {
        Listing storage nftInfo = nfts[_listingId];
        require(nftInfo.isActive, "NFT is not active");
        require(nftInfo.seller == msg.sender, "Only seller can delist");
        
        //标记为已下架
        nftInfo.isActive = false;
        
        //触发事件
        emit NFTList(_listingId, msg.sender, nftInfo.nftAddress, nftInfo.tokenId, 0); // price设为0表示下架
    }
    
    // 实现IERC721Receiver接口（虽然在你的设计中不需要接收NFT，但为了接口完整性）
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
