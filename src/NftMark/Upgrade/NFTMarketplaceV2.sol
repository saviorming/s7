pragma solidity ^0.8.25;

import "./NFTMarketplaceV1.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

/**
 * @title NFTMarketplaceV2
 * @dev 加⼊离线签名上架 NFT 功能⽅法（签名内容：tokenId， 价格），
 * 实现⽤户⼀次性使用 setApproveAll 给 NFT 市场合约，每个 NFT 上架时仅需使⽤签名上架
 * 采用UUPS升级模式
 */
contract NFTMarketplaceV2 is NFTMarketplaceV1, EIP712Upgradeable{
    //
    using ECDSA for bytes32;

   // 记录用户的nonce，防止重放攻击
    mapping(address => uint256) public nonces;

    //只允许初始化一次
    constructor() {
        _disableInitializers();
    }
        // 签名所需的上架参数结构
    struct ListingParams {
        address nftContract;  // NFT合约地址
        uint256 tokenId;      // NFT ID
        uint256 price;        // 售价（以paymentToken为单位）
        uint256 nonce;        // 防止重放攻击的随机数
        uint256 deadline;     // 签名有效期（时间戳）
    }

    //设置初始化函数
    function initializeV2() reinitializer(2) external {
        __EIP712_init("NFTMarketplaceV2", "1");
    }

    /**
     * @dev 通过离线签名上架NFT
     * 用户只需提前调用一次setApprovalForAll授权市场合约
     * @param params 上架参数
     * @param signature 签名数据
     */
    function listNFTWithSignature(ListingParams memory params,bytes memory signature) external {
        
         // 验证签名是否过期
        require(block.timestamp <= params.deadline, unicode"V2: 签名已过期");
        // 验证价格有效性
        require(params.price > 0, unicode"V2: 价格必须大于0");
        // 验证NFT合约地址有效性
        require(params.nftContract != address(0), unicode"V2: NFT合约地址无效");
        // 验证tokenId有效性
        require(params.tokenId > 0, unicode"V2: tokenId必须大于0");
        // 验证签名者身份
        bytes32 digest = _getSignatureHash(params);
        address signer = digest.recover(signature);
        IERC721 nft = IERC721(params.nftContract);
        require(signer == nft.ownerOf(params.tokenId), unicode"V2: 签名者身份无效");
           // 验证签名者已授权市场合约转移NFT（一次授权，多次使用）
        require(nft.isApprovedForAll(signer, address(this)), unicode"V2: 市场未获得NFT授权");
        // 验证nonce有效性，防止重放攻击
        require(params.nonce == nonces[signer], unicode"V2: 无效的nonce");
        nonces[signer]++;
        // 执行上架操作
        // 存储订单信息
        nfts[orderIdCounter] = NFTinfo({
            seller: signer,  // 修复：seller 应该是签名者，不是调用者
            nftAddress: params.nftContract,
            tokenId: params.tokenId,
            price: params.price,
            isActive: true,
            listingTime: block.timestamp
        });
        
        // 发出上架事件
        emit NFTListed(orderIdCounter, signer, params.nftContract, params.tokenId, params.price);
        
        // 增加订单ID计数器和NFT计数
        orderIdCounter++;
        nftCount++;
    }


        /**
     * @dev 生成ListingParams的结构体哈希
     */
    function _hashListingParams(ListingParams memory params) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            keccak256("ListingParams(address nftContract,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"),
            params.nftContract,
            params.tokenId,
            params.price,
            params.nonce,
            params.deadline
        ));
    }

    /**
     * @dev 生成EIP712标准的签名哈希
     */
    function _getSignatureHash(ListingParams memory params) internal view returns (bytes32) {
        return _hashTypedDataV4(_hashListingParams(params));
    }

    /**
     * @dev 获取用户当前的nonce值
     * @param user 用户地址
     * @return 当前nonce值
     */
    function getUserNonce(address user) external view returns (uint256) {
        return nonces[user];
    }
}