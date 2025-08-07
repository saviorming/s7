pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Erc20TokenWithPermit.sol";
import "../BasicVersion/NFTMarket.sol";
import "forge-std/console.sol";

contract AirdopMerkleNFTMarket is NFTMarket {
    // 支持permit的代币合约
    IERC20Permit public payTokenPermit;
    // Merkle Tree 根哈希，用于白名单验证
    bytes32 public merkleRoot;
    // 市场管理员admin，用于支付折扣差价
    address public admin;

    constructor(address _token, bytes32 _merkleRoot, address _admin) NFTMarket(_token) {
        payTokenPermit = IERC20Permit(_token);
        merkleRoot = _merkleRoot;
        admin = _admin;
    }

    // 临时存储 permit 授权信息，用于 multicall
    struct PermitData {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bool isUsed;
    }
    
    mapping(address => PermitData) public permitDatas;
    // 标记为已使用白名单
    mapping(address => bool) public hasClaimedWhitelist;

    // 事件
    event WhitelistClaimed(address indexed user, uint256 indexed marketId, uint256 discountPrice, uint256 adminPaid);
    event PermitPrePaid(address indexed owner, address indexed spender, uint256 value);

    // permitPrePay() : 调用token的 permit 进行授权
    function permitPrePay(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // 存储授权信息用于验证
        permitDatas[owner] = PermitData(owner, spender, value, deadline, v, r, s, false);
        
        // 执行Permit授权
        payTokenPermit.permit(owner, spender, value, deadline, v, r, s);
        
        emit PermitPrePaid(owner, spender, value);
        console.log("Permit executed for owner:", owner);
        console.log("Spender:", spender);
        console.log("Value:", value);
    }

    // 验证默克尔树,用户需要传入proof来验证 
    function checkWhiteList(address user, bytes32[] calldata proof) public view returns(bool) {
        // 用默克尔树开始验证
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    function claimNFT(uint256 _marketId, bytes32[] calldata proof) public nonReentrant returns(bool) {
        // 验证默克尔树
        require(checkWhiteList(msg.sender, proof), "Not in whitelist");
        
        // 验证是否已经使用白名单
        require(!hasClaimedWhitelist[msg.sender], "Already claimed whitelist discount");
        
        // 验证NFT是否已经上架
        NFTinfo memory nftInfo = nfts[_marketId];
        require(nftInfo.isActive, "NFT not listed");
        require(nftInfo.seller != msg.sender, "Cannot buy your own NFT");
        
        // 验证是否已经通过permitPrePay授权
        PermitData storage permitData = permitDatas[msg.sender];
        require(permitData.owner == msg.sender, "No permit authorization found");
        require(!permitData.isUsed, "Permit already used");
        require(permitData.spender == address(this), "Permit not for this contract");
        
        uint256 originalPrice = nftInfo.price;
        uint256 discountPrice = originalPrice / 2; // 50% 折扣
        uint256 adminPayment = originalPrice - discountPrice; // admin需要支付的差价
        
        // 验证用户余额足够支付折扣价格
        require(payToken.balanceOf(msg.sender) >= discountPrice, "Insufficient balance for discount price");
        
        // 验证admin余额足够支付差价
        require(payToken.balanceOf(admin) >= adminPayment, "Admin insufficient balance for discount");
        
        // 标记为已使用白名单和permit
        hasClaimedWhitelist[msg.sender] = true;
        permitData.isUsed = true;
        
        // 更新NFT状态
        nfts[_marketId].isActive = false;
        nftCount -= 1;
        
        // 用户支付折扣价格给卖家
        require(payToken.transferFrom(msg.sender, nftInfo.seller, discountPrice), "User payment failed");
        
        // admin支付差价给卖家
        require(payToken.transferFrom(admin, nftInfo.seller, adminPayment), "Admin payment failed");
        
        // 转移NFT
        IERC721(nftInfo.nftAddress).safeTransferFrom(nftInfo.seller, msg.sender, nftInfo.tokenId);
        
        emit WhitelistClaimed(msg.sender, _marketId, discountPrice, adminPayment);
        emit NFTSold(_marketId, nftInfo.seller, nftInfo.tokenId, msg.sender, originalPrice);
        
        return true;
    }

    // Multicall 功能 - 使用 delegatecall 方式
    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(data[i]);
            require(success, "Multicall failed");
            results[i] = result;
        }
        return results;
    }

    // 设置新的merkle root (仅owner)
    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    // 设置新的admin (仅owner)
    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    // 查询用户是否已使用白名单
    function hasUserClaimedWhitelist(address user) external view returns (bool) {
        return hasClaimedWhitelist[user];
    }

    // 查询用户的permit数据
    function getUserPermitData(address user) external view returns (PermitData memory) {
        return permitDatas[user];
    }
}