pragma solidity ^0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";


/**
 * @title NFTMarketplaceV1
 * @dev 第一版NFT市场合约，支持基础的上架、下架和使用ERC20代币购买功能
 * 采用UUPS升级模式
 */
contract NFTMarketplaceV1 is Initializable,
    UUPSUpgradeable,OwnableUpgradeable,ReentrancyGuardUpgradeable{
    
    // 订单自增的id
    uint256 public orderIdCounter;

    //用于支付的erc20代币
    IERC20 public paymentToken; 

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

        //上架事件
    event NFTListed(uint256 nftMarketId, address seller, address nftAddress, uint256 tokenId, uint256 price);
    //下架事件
    event NFTDeList(uint256 nftMarketId,address seller,uint256 tokenId);
    //购买事件
    event NFTSold(uint256 nftMarketId, address seller, uint256 tokenId, address buyer, uint256 price);


    //只允许初始化一次
    constructor(){
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，部署时调用
     * @param _paymentToken 用于支付的ERC20代币地址
    * @param initialOwner 初始所有者地址
     */
    function initialize(
        address _paymentToken,
        address initialOwner
    ) external initializer {
        require(_paymentToken != address(0), unicode"V1: 支付代币地址无效");
        __Ownable_init(initialOwner);
        orderIdCounter = 1; // 订单ID从1开始
        paymentToken = IERC20(_paymentToken);
    }

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
        nfts[orderIdCounter] = NFTinfo(msg.sender, _nftAddress, _tokenId,_price,true,block.timestamp);
        emit NFTListed(orderIdCounter,msg.sender, _nftAddress, _tokenId,_price);
        orderIdCounter++;
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
        require(paymentToken.balanceOf(msg.sender) >= nftInfo.price,"token not enough");
        address seller = nftInfo.seller;
        uint256 price = nftInfo.price;
        //更新nft的状态
        nftInfo.isActive = false;
        nftCount -= 1;
        //转账代币
        bool success = paymentToken.transferFrom(msg.sender, seller, price);
        require(success,"Token transfer failed");
        //划转nft,之前上架的时候确保过已经授权给合约市场
        IERC721(nftInfo.nftAddress).safeTransferFrom(seller, msg.sender, nftInfo.tokenId);
        emit NFTSold(_nftMarketId, seller, nftInfo.tokenId, msg.sender, price);
        return true;
    }




    //  UUPS升级授权
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}