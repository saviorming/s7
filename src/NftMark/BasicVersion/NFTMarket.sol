pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BaseErc20Token.sol";

contract NFTMarket is Ownable, IERC20Callback, ReentrancyGuard{
    //限定只能用指定的合约代币进行购买 
    ERC20 public payToken;
    //定义nft结构体
    struct NFTinfo{
        // 持有人
        address seller;
        //NFT合约地址
        address nftAddress;
        //nft tokenId
        uint256 tokenId;
        //售价
        uint256 price;
        //是否上架标识 true：上架 false：下架
        bool isActive;
        //上架时间
        uint256 listingTime;
    }
    //已上架的token,key为NFT市场给自增的id
    mapping(uint256 => NFTinfo) public nfts;
    //已上架的token数量
    uint256 public nftCount;
    //用户已上架的nft -- 不需要，因为如果涉及下架需要到数组中找到对应的nft信息，然后改变状态
    //这样会损耗非常多的gas没有必要，正常情况让前端进行排序处理比较好，这里只是做一个记录，不推荐使用
    mapping(address => uint256[]) public userNfts;
    //nft市场的记数
    uint256 nftMarketId;
    // 存储已生效的nft，用于展示
    uint256[] public listingIds; 

    constructor(address _tokenAddress) Ownable(msg.sender){
        payToken = ERC20(_tokenAddress);
    }

    //上架事件
    event NFTListed(uint256 nftMarketId, address seller, address nftAddress, uint256 tokenId, uint256 price);
    //下架事件
    event NFTDeList(uint256 nftMarketId,address seller,uint256 tokenId);
    //购买事件
    event NFTSold(uint256 nftMarketId, address seller, uint256 tokenId, address buyer, uint256 price);

    //===================上架nft===================
    // 调用之前都需要进行授权，对应的nft没有存入到合约中，还在用户手上等购买时
    // 合约市场会从用户手上转移nft到购买者手中
    /**
     * @dev 上架nft
     * @param _nftAddress nft合约地址
     * @param _tokenId nft tokenId
     * @param _price 上架价格
     * @return 是否成功
     */
    function list(address _nftAddress,uint256 _tokenId,uint256 _price) external returns (bool){
        //只能支持nft
        IERC721 nft = IERC721(_nftAddress);
        require(nft.ownerOf(_tokenId) == msg.sender, "Not NFT owner");
        require(_nftAddress != address(0),"nftAddress is zero");
        require(_price > 0,"price is zero");
        //判断是否已授权
        require(nft.getApproved(_tokenId) == address(this) || 
                nft.isApprovedForAll(msg.sender,address(this)),
                "nft not approved");
        nfts[nftMarketId] = NFTinfo(msg.sender, _nftAddress, _tokenId,_price,true,block.timestamp);
        userNfts[msg.sender].push(nftMarketId);
        listingIds.push(nftMarketId);
        emit NFTListed(nftMarketId,msg.sender, _nftAddress, _tokenId,_price);
        nftMarketId++;
        nftCount+=1;
        return true;
    }

    //============下架nft===============
    function delist(uint256 _nftMarketId) external returns (bool){
        NFTinfo storage nftInfo = nfts[_nftMarketId];
        require(nftInfo.isActive,"nft not active");
        require(nftInfo.seller == msg.sender,"only seller can delist");
        nftInfo.isActive = false;
        nftCount-=1;
        emit NFTDeList(_nftMarketId,msg.sender,nftInfo.tokenId);
        return true;
    }

    //=========购买nft========
    function buyNFT(uint256 _nftMarketId) public virtual nonReentrant returns (bool){
        NFTinfo storage nftInfo = nfts[_nftMarketId];
        require(nftInfo.isActive,"nft not active");
        require(nftInfo.seller != msg.sender, "Cannot buy your own NFT");
        require(payToken.balanceOf(msg.sender) >= nftInfo.price,"token not enough");
        
        address seller = nftInfo.seller;
        uint256 price = nftInfo.price;
        
        //更新nft的状态
        nftInfo.isActive = false;
        nftCount -= 1;
        
        //转账代币
        bool success = payToken.transferFrom(msg.sender, seller, price);
        require(success,"Token transfer failed");
        
        //划转nft,之前上架的时候确保过已经授权给合约市场
        IERC721(nftInfo.nftAddress).safeTransferFrom(seller, msg.sender, nftInfo.tokenId);
        
        emit NFTSold(_nftMarketId, seller, nftInfo.tokenId, msg.sender, price);
        return true;
    }

    //回调,用于用户直接向市场进行了转账，并指定了对应的nft的listingId
    function tokensReceived(address sender, uint256 amount, bytes memory data) external override nonReentrant{
        //验证是否是指定的token
        require(msg.sender == address(payToken), "Only token contract can call");
        uint256 buyNftId = abi.decode(data,(uint256));
        NFTinfo storage nftInfo = nfts[buyNftId];
        //验证是否存在且是上架状态
        require(nftInfo.isActive,"can't find the nft");
        require(nftInfo.seller != sender, "Cannot buy your own NFT");
        require(amount >= nftInfo.price,"price not enough");
        
        address seller = nftInfo.seller;
        uint256 price = nftInfo.price;
        
        //更新nft的状态
        nftInfo.isActive = false;
        nftCount -= 1;
        
        //验证如果对应的金额超出nft的价格，需要将超出的部分返还回去
        if(amount > price){
            require(payToken.transfer(sender, amount - price),"Refund failed");
        } 
        
        //将对应的金额转给卖家
        require(payToken.transfer(seller, price),"Payment to seller failed");
        
        //转移对应的nft
        IERC721(nftInfo.nftAddress).safeTransferFrom(seller, sender, nftInfo.tokenId);
        
        emit NFTSold(buyNftId, seller, nftInfo.tokenId, sender, price);
    }

    // ========== 查询功能 ==========
    
    /**
     * @dev 获取活跃的NFT列表
     * @return 活跃的NFT市场ID数组
     */
    function getActiveListings() external view returns (uint256[] memory) {
        uint256[] memory activeListings = new uint256[](nftCount);
        uint256 activeIndex = 0;
        
        for (uint256 i = 0; i < listingIds.length; i++) {
            if (nfts[listingIds[i]].isActive) {
                activeListings[activeIndex] = listingIds[i];
                activeIndex++;
            }
        }
        
        // 创建正确大小的数组
        uint256[] memory result = new uint256[](activeIndex);
        for (uint256 i = 0; i < activeIndex; i++) {
            result[i] = activeListings[i];
        }
        
        return result;
    }
    
    /**
     * @dev 获取用户的上架历史
     * @param user 用户地址
     * @return 用户的NFT市场ID数组
     */
    function getUserListings(address user) external view returns (uint256[] memory) {
        return userNfts[user];
    }
    
    /**
     * @dev 获取NFT详细信息
     * @param _nftMarketId NFT市场ID
     * @return NFT详细信息
     */
    function getNFTInfo(uint256 _nftMarketId) external view returns (NFTinfo memory) {
        return nfts[_nftMarketId];
    }
    
    /**
     * @dev 获取当前NFT市场ID计数器
     * @return 当前的nftMarketId值
     */
    function getCurrentMarketId() external view returns (uint256) {
        return nftMarketId;
    }
}