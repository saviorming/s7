pragma solidity ^0.8.25;

import "../src/ExtendedERC20/AirdopMerkleNFTMarket.sol";
import "../src/ExtendedERC20/ExtendedERC20WithPermit.sol";
import "../src/ExtendedERC20/SimpleNFT.sol";

/**
 * @title AirdopMerkleNFTMarket 使用示例
 * @dev 展示如何使用 AirdopMerkleNFTMarket 合约的核心功能
 */
contract AirdopMerkleNFTMarketExample {
    AirdopMerkleNFTMarket public market;
    ExtendedERC20WithPermit public token;
    SimpleNFT public nft;
    
    // 示例白名单用户
    address public whitelistUser = 0x1234567890123456789012345678901234567890;
    address public regularUser = 0x2345678901234567890123456789012345678901;
    address public seller = 0x3456789012345678901234567890123456789012;
    
    constructor() {
        // 1. 部署所有合约
        token = new ExtendedERC20WithPermit();
        nft = new SimpleNFT();
        
        // 2. 创建简单的 Merkle Root（实际应用中需要使用专门的库）
        bytes32 merkleRoot = keccak256(abi.encodePacked(whitelistUser));
        market = new AirdopMerkleNFTMarket(address(token), merkleRoot);
        
        // 3. 初始化数据
        setupExample();
    }
    
    function setupExample() internal {
        // 分配代币给用户
        token.transfer(whitelistUser, 1000 * 10**18);
        token.transfer(regularUser, 1000 * 10**18);
        
        // 为卖家铸造 NFT
        nft.mint(seller);
        nft.mint(seller);
    }
    
    /**
     * @dev 示例1: 卖家上架 NFT
     */
    function exampleListNFT() external {
        // 模拟卖家操作
        // 1. 授权市场合约操作 NFT
        // nft.approve(address(market), tokenId);
        
        // 2. 上架 NFT
        // market.list(address(nft), tokenId, price);
        
        // 实际调用（需要在正确的上下文中执行）
        // market.list(address(nft), 0, 100 * 10**18);
    }
    
    /**
     * @dev 示例2: 普通用户购买 NFT
     */
    function exampleRegularBuy() external {
        // 模拟普通用户购买
        // 1. 授权代币
        // token.approve(address(market), price);
        
        // 2. 购买 NFT
        // market.buyNFT(listingId);
    }
    
    /**
     * @dev 示例3: 白名单用户使用 permit + multicall 购买 NFT（50% 折扣）
     */
    function exampleWhitelistBuyWithMulticall() external {
        // 这是最复杂的功能，展示了三个核心技术的组合使用
        
        // 1. 准备 permit 签名数据
        uint256 value = 50 * 10**18; // 折扣价格
        uint256 deadline = block.timestamp + 1 hours;
        
        // 2. 生成 EIP-712 签名（实际应用中需要前端或钱包支持）
        // bytes32 structHash = keccak256(abi.encode(...));
        // bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        // (uint8 v, bytes32 r, bytes32 s) = sign(privateKey, hash);
        
        // 3. 准备 Merkle Proof（实际应用中需要从 Merkle Tree 生成）
        bytes32[] memory merkleProof = new bytes32[](0); // 简化的单节点树
        
        // 4. 使用 multicall 一次性执行 permit + claimNFT
        // market.permitAndClaimNFT(
        //     whitelistUser,           // owner
        //     address(market),         // spender  
        //     value,                   // value
        //     deadline,                // deadline
        //     v, r, s,                 // signature
        //     listingId,               // NFT listing ID
        //     merkleProof              // Merkle proof
        // );
    }
    
    /**
     * @dev 示例4: 分步执行白名单购买
     */
    function exampleWhitelistBuyStepByStep() external {
        // 方式二：分步执行
        
        // 1. 先执行 permit 授权
        // market.permitPrePay(owner, spender, value, deadline, v, r, s);
        
        // 2. 再执行白名单购买
        // market.claimNFT(listingId, merkleProof);
    }
    
    /**
     * @dev 获取合约状态信息
     */
    function getContractInfo() external view returns (
        address tokenAddress,
        address nftAddress,
        address marketAddress,
        uint256 activeListingsCount
    ) {
        tokenAddress = address(token);
        nftAddress = address(nft);
        marketAddress = address(market);
        
        uint256[] memory activeListings = market.getActiveListings();
        activeListingsCount = activeListings.length;
    }
    
    /**
     * @dev 验证白名单状态
     */
    function checkWhitelistStatus(address user) external view returns (bool) {
        bytes32[] memory proof = new bytes32[](0); // 简化的证明
        return market.verifyWhitelist(user, proof);
    }
    
    /**
     * @dev 获取 NFT 的折扣价格
     */
    function getDiscountPrice(uint256 listingId) external view returns (uint256) {
        return market.getDiscountedPrice(listingId);
    }
}

/**
 * @title 使用说明和最佳实践
 * 
 * ## 核心功能组合
 * 
 * 1. **MerkleTree 白名单验证**
 *    - 使用 Merkle Tree 存储白名单，节省 gas
 *    - 用户提供 Merkle Proof 证明自己在白名单中
 *    - 白名单用户享受 50% 折扣
 * 
 * 2. **Permit 授权**
 *    - 基于 EIP-2612 标准
 *    - 用户通过签名授权，无需单独的 approve 交易
 *    - 提升用户体验，节省 gas
 * 
 * 3. **Multicall 批量调用**
 *    - 使用 delegatecall 在一个交易中执行多个操作
 *    - 特别适用于 permit + claimNFT 的组合
 *    - 原子性操作，要么全部成功要么全部失败
 * 
 * ## 实际应用流程
 * 
 * ### 对于项目方：
 * 1. 生成包含白名单地址的 Merkle Tree
 * 2. 部署合约时设置 Merkle Root
 * 3. 为每个白名单用户生成对应的 Merkle Proof
 * 
 * ### 对于白名单用户：
 * 1. 获取自己的 Merkle Proof
 * 2. 生成 permit 签名（通过钱包或前端）
 * 3. 调用 permitAndClaimNFT 一次性完成购买
 * 
 * ### 对于普通用户：
 * 1. approve 代币给市场合约
 * 2. 调用 buyNFT 购买 NFT
 * 
 * ## 安全考虑
 * 
 * 1. **重入攻击防护**: 使用 ReentrancyGuard
 * 2. **签名重放攻击**: permit 包含 nonce 防重放
 * 3. **白名单滥用**: 每个地址只能使用一次白名单折扣
 * 4. **权限控制**: 严格的所有权和授权检查
 * 
 * ## Gas 优化
 * 
 * 1. **Merkle Tree**: 相比存储所有白名单地址，大幅节省存储成本
 * 2. **Permit**: 减少一次 approve 交易
 * 3. **Multicall**: 将多个操作合并为一个交易
 * 
 * ## 扩展性
 * 
 * 该合约设计具有良好的扩展性，可以轻松添加：
 * - 多级折扣系统
 * - 时间限制的白名单
 * - 动态定价机制
 * - 版税分成功能
 */