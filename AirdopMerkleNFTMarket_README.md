# AirdopMerkleNFTMarket 合约

这是一个集成了 **MerkleTree 白名单**、**Permit 授权** 和 **Multicall** 功能的 NFT 市场合约。白名单用户可以享受 50% 的折扣购买 NFT。

## 功能特性

### 1. MerkleTree 白名单验证
- 使用 Merkle Tree 验证用户是否在白名单中
- 白名单用户可以享受 50% 的折扣
- 每个用户只能使用一次白名单折扣

### 2. Permit 授权
- 支持 EIP-2612 Permit 标准
- 用户可以通过签名进行授权，无需单独的 approve 交易
- 节省 gas 费用和交易步骤

### 3. Multicall 功能
- 支持在一个交易中执行多个函数调用
- 使用 delegatecall 方式实现
- 特别适用于 permit + claimNFT 的组合操作

## 合约架构

```
AirdopMerkleNFTMarket
├── ExtendedERC20WithPermit (支持 permit 的 ERC20 代币)
├── SimpleNFT (ERC721 NFT 合约)
└── MerkleTree 白名单验证
```

## 主要函数

### 上架和购买
- `list(address nftAddress, uint256 tokenId, uint256 price)` - 上架 NFT
- `buyNFT(uint256 listingId)` - 普通购买 NFT
- `delist(uint256 listingId)` - 下架 NFT

### 白名单功能
- `permitPrePay(...)` - 执行 permit 授权
- `claimNFT(uint256 listingId, bytes32[] merkleProof)` - 白名单用户购买 NFT
- `permitAndClaimNFT(...)` - 组合函数，一次性执行 permit 和购买

### Multicall
- `multicall(bytes[] calldata data)` - 批量执行函数调用

### 查询函数
- `getActiveListings()` - 获取所有活跃的上架列表
- `getDiscountedPrice(uint256 listingId)` - 获取折扣价格
- `verifyWhitelist(address user, bytes32[] merkleProof)` - 验证白名单

## 使用流程

### 普通用户购买流程
```solidity
// 1. 授权代币
token.approve(marketAddress, price);

// 2. 购买 NFT
market.buyNFT(listingId);
```

### 白名单用户购买流程（方式一：分步执行）
```solidity
// 1. 执行 permit 授权
market.permitPrePay(owner, spender, value, deadline, v, r, s);

// 2. 使用白名单购买
market.claimNFT(listingId, merkleProof);
```

### 白名单用户购买流程（方式二：一次性执行）
```solidity
// 使用 multicall 一次性执行
market.permitAndClaimNFT(
    owner, spender, value, deadline, v, r, s,  // permit 参数
    listingId, merkleProof                      // claimNFT 参数
);
```

### 卖家上架流程
```solidity
// 1. 授权 NFT
nft.approve(marketAddress, tokenId);

// 2. 上架 NFT
market.list(nftAddress, tokenId, price);
```

## 部署和测试

### 编译合约
```bash
forge build
```

### 运行测试
```bash
forge test --match-contract AirdopMerkleNFTMarketTest -vv
```

### 部署合约
```bash
forge script script/AirdopMerkleNFTMarket.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

## 安全考虑

1. **重入攻击防护**: 使用 `ReentrancyGuard` 防止重入攻击
2. **权限控制**: 只有 NFT 所有者可以上架，只有卖家可以下架
3. **白名单限制**: 每个用户只能使用一次白名单折扣
4. **Permit 验证**: 严格验证 permit 签名的有效性

## 事件

- `NFTList(uint256 indexed listingId, address indexed seller, address indexed nftContract, uint256 tokenId, uint256 price)`
- `NFTBuy(uint256 indexed listingId, address indexed buyer, address indexed seller, address nftContract, uint256 tokenId, uint256 price)`
- `WhitelistClaim(address indexed user, uint256 indexed listingId, uint256 discountedPrice)`

## 注意事项

1. **Merkle Tree 生成**: 实际应用中需要使用专门的工具生成 Merkle Tree 和 Proof
2. **Permit 签名**: 需要正确实现 EIP-712 签名流程
3. **Gas 优化**: Multicall 可以节省 gas，但需要注意调用顺序
4. **权限管理**: 实际应用中可能需要更复杂的权限控制机制

## 扩展功能

可以考虑添加的功能：
- 拍卖机制
- 版税分成
- 批量操作
- 价格预言机集成
- 更复杂的折扣策略

## 技术栈

- Solidity ^0.8.25
- OpenZeppelin Contracts
- Foundry (测试和部署)
- Merkle Tree (白名单验证)
- EIP-2612 Permit (授权)