pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "forge-std/console.sol";

contract AirdopMerkleNFTMarket is ReentrancyGuard {
    // 支持 permit 的 token
    IERC20 public payToken;
    IERC20Permit public payTokenPermit;
    
    // Merkle Tree 根哈希，用于白名单验证
    bytes32 public merkleRoot;
    
    // 上架结构体
    struct Listing {
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
        bool isActive;
        uint256 listingTime;
    }
    
    // 存储已生效的nft，用于展示
    uint256[] public listingIds;
    
    // 存储已上架的NFT
    mapping(uint256 => Listing) public nfts;
    
    // 自增id，每次上架一个nft就自增一次，用来做定位
    uint256 public listingId;
    
    // 记录已经使用过白名单的用户，防止重复使用
    mapping(address => bool) public hasClaimedWhitelist;
    
    // 临时存储 permit 授权信息，用于 multicall
    struct PermitData {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    
    PermitData private tempPermitData;
    bool private permitExecuted;
    
    constructor(address _tokenAddress, bytes32 _merkleRoot) {
        payToken = IERC20(_tokenAddress);
        payTokenPermit = IERC20Permit(_tokenAddress);
        merkleRoot = _merkleRoot;
    }
    
    event NFTList(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price);
    event NFTBuy(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price);
    event WhitelistClaim(address indexed user, uint256 indexed listingId, uint256 discountedPrice);
    
    // 上架 NFT
    function list(address nftAddress, uint256 tokenId, uint256 price) external {
        IERC721 nft = IERC721(nftAddress);
        require(nft.ownerOf(tokenId) == msg.sender, "Not NFT owner");
        require(
            nft.getApproved(tokenId) == address(this) ||
            nft.isApprovedForAll(msg.sender, address(this)),
            "Market not approved"
        );
        require(price > 0, "Price must be greater than 0");
        
        nfts[listingId] = Listing(msg.sender, nftAddress, tokenId, price, true, block.timestamp);
        listingIds.push(listingId);
        
        emit NFTList(listingId, msg.sender, nftAddress, tokenId, price);
        listingId++;
    }
    
    // 普通购买 NFT（非白名单用户）
    function buyNFT(uint256 _listingId) external nonReentrant {
        Listing storage nftInfo = nfts[_listingId];
        require(nftInfo.isActive, "NFT is not active");
        require(nftInfo.seller != msg.sender, "Cannot buy your own NFT");
        require(payToken.balanceOf(msg.sender) >= nftInfo.price, "Insufficient balance");
        
        uint256 price = nftInfo.price;
        address seller = nftInfo.seller;
        
        nftInfo.isActive = false;
        
        bool success = payToken.transferFrom(msg.sender, seller, price);
        require(success, "Token transfer failed");
        
        IERC721(nftInfo.nftAddress).safeTransferFrom(seller, msg.sender, nftInfo.tokenId);
        
        emit NFTBuy(_listingId, msg.sender, seller, nftInfo.nftAddress, nftInfo.tokenId, price);
    }
    
    // Permit 预授权函数
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 存储 permit 数据以供后续使用
        tempPermitData = PermitData(owner, spender, value, deadline, v, r, s);
        
        // 执行 permit 授权
        payTokenPermit.permit(owner, spender, value, deadline, v, r, s);
        permitExecuted = true;
        
        console.log("Permit executed for owner:", owner);
        console.log("Spender:", spender);
        console.log("Value:", value);
    }
    
    // 白名单用户通过 Merkle 证明购买 NFT（50% 折扣）
    function claimNFT(
        uint256 _listingId,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        // 验证 permit 是否已执行
        require(permitExecuted, "Permit not executed");
        require(tempPermitData.owner == msg.sender, "Permit owner mismatch");
        
        // 验证白名单
        require(!hasClaimedWhitelist[msg.sender], "Already claimed whitelist discount");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid merkle proof");
        
        // 验证 NFT 信息
        Listing storage nftInfo = nfts[_listingId];
        require(nftInfo.isActive, "NFT is not active");
        require(nftInfo.seller != msg.sender, "Cannot buy your own NFT");
        
        // 计算折扣价格（50% 折扣）
        uint256 discountedPrice = nftInfo.price / 2;
        require(tempPermitData.value >= discountedPrice, "Insufficient permit value");
        
        address seller = nftInfo.seller;
        
        // 标记为已使用白名单和已售出
        hasClaimedWhitelist[msg.sender] = true;
        nftInfo.isActive = false;
        
        // 使用 permit 授权进行转账
        bool success = payToken.transferFrom(msg.sender, seller, discountedPrice);
        require(success, "Token transfer failed");
        
        // 转移 NFT
        IERC721(nftInfo.nftAddress).safeTransferFrom(seller, msg.sender, nftInfo.tokenId);
        
        // 清理临时数据
        delete tempPermitData;
        permitExecuted = false;
        
        emit WhitelistClaim(msg.sender, _listingId, discountedPrice);
        emit NFTBuy(_listingId, msg.sender, seller, nftInfo.nftAddress, nftInfo.tokenId, discountedPrice);
    }
    
    // Multicall 实现（使用 delegatecall）
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "Multicall: call failed");
            results[i] = result;
        }
        
        return results;
    }
    
    // 组合调用：permit + claimNFT
    function permitAndClaimNFT(
        // permit 参数
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        // claimNFT 参数
        uint256 _listingId,
        bytes32[] calldata merkleProof
    ) external {
        // 构造 multicall 数据
        bytes[] memory calls = new bytes[](2);
        
        // 第一个调用：permitPrePay
        calls[0] = abi.encodeWithSelector(
            this.permitPrePay.selector,
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s
        );
        
        // 第二个调用：claimNFT
        calls[1] = abi.encodeWithSelector(
            this.claimNFT.selector,
            _listingId,
            merkleProof
        );
        
        // 执行 multicall
        this.multicall(calls);
    }
    
    // 下架功能
    function delist(uint256 _listingId) external {
        Listing storage nftInfo = nfts[_listingId];
        require(nftInfo.isActive, "NFT is not active");
        require(nftInfo.seller == msg.sender, "Only seller can delist");
        
        nftInfo.isActive = false;
        
        emit NFTList(_listingId, msg.sender, nftInfo.nftAddress, nftInfo.tokenId, 0);
    }
    
    // 更新 Merkle Root（仅限合约部署者，实际应用中可能需要更复杂的权限控制）
    function updateMerkleRoot(bytes32 _newMerkleRoot) external {
        // 简化实现，实际应用中应该有适当的权限控制
        merkleRoot = _newMerkleRoot;
    }
    
    // 获取上架列表
    function getActiveListings() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        
        // 计算活跃的上架数量
        for (uint256 i = 0; i < listingIds.length; i++) {
            if (nfts[listingIds[i]].isActive) {
                activeCount++;
            }
        }
        
        // 创建活跃上架数组
        uint256[] memory activeListings = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < listingIds.length; i++) {
            if (nfts[listingIds[i]].isActive) {
                activeListings[index] = listingIds[i];
                index++;
            }
        }
        
        return activeListings;
    }
    
    // 获取折扣价格
    function getDiscountedPrice(uint256 _listingId) external view returns (uint256) {
        require(nfts[_listingId].isActive, "NFT is not active");
        return nfts[_listingId].price / 2;
    }
    
    // 验证用户是否在白名单中
    function verifyWhitelist(address user, bytes32[] calldata merkleProof) external view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
    
    // 实现 IERC721Receiver 接口
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}