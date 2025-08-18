# 看涨期权Token (Call Option Token)

一个基于ERC20标准的看涨期权Token智能合约系统，允许用户创建、交易和行权ETH看涨期权。

## 📋 功能特性

### 核心功能
- **期权创建**: 项目方可以设定行权价格、到期时间和标的价格创建期权
- **期权发行**: 项目方存入ETH，按1:1比例发行期权Token
- **期权交易**: 期权Token可以与USDT创建交易对，模拟期权购买
- **期权行权**: 用户在到期日可按行权价格用期权Token兑换ETH
- **过期销毁**: 项目方可在过期后销毁未行权的期权Token并赎回ETH

### 安全特性
- **重入攻击防护**: 使用OpenZeppelin的ReentrancyGuard
- **权限控制**: 基于Ownable的访问控制
- **安全转账**: 使用call方法替代transfer，避免gas限制问题
- **完整事件日志**: 所有重要操作都有事件记录
- **错误处理**: 自定义错误类型，提供清晰的错误信息

## 🏗️ 合约架构

### 主要合约

1. **CallOptionToken.sol** - 主要的期权Token合约
   - 继承ERC20, Ownable, ReentrancyGuard
   - 实现期权的完整生命周期管理

2. **MockUSDT.sol** - USDT模拟合约
   - 用于与期权Token创建交易对
   - 支持铸造、销毁、批量转账等功能

### 关键参数

```solidity
struct OptionParameters {
    uint256 strikePrice;      // 行权价格 (wei)
    uint256 expirationTime;   // 到期时间 (timestamp)
    uint256 underlyingPrice;  // 创建时标的价格 (wei)
}
```

## 🚀 快速开始

### 环境要求

- Foundry (forge, cast, anvil)
- Solidity ^0.8.19
- OpenZeppelin Contracts

### 安装依赖

```bash
# 安装Foundry (如果还没有安装)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 初始化项目
forge init

# 安装OpenZeppelin合约
forge install OpenZeppelin/openzeppelin-contracts
```

### 编译合约

```bash
forge build
```

### 运行测试

```bash
# 运行所有测试
forge test

# 运行特定测试并显示详细输出
forge test --match-test testCompleteOptionLifecycle -vvv

# 运行Fuzz测试
forge test --match-test testFuzz -vvv
```

### 部署合约

```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key_here
export RPC_URL=your_rpc_url_here

# 部署到本地测试网
forge script script/DeployCallOption.s.sol:DeployCallOption --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# 部署并演示功能
forge script script/DeployCallOption.s.sol:DeployAndDemo --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

## 📖 使用指南

### 1. 创建期权

```solidity
// 部署期权合约
CallOptionToken option = new CallOptionToken(
    "ETH Call Option 2000",  // 名称
    "ETH-CALL-2000",         // 符号
    2000 ether,              // 行权价格
    block.timestamp + 7 days, // 到期时间
    1800 ether               // 当前ETH价格
);
```

### 2. 发行期权Token

```solidity
// 项目方存入10 ETH，发行10个期权Token
option.issueOptions{value: 10 ether}();
```

### 3. 转账期权Token

```solidity
// 转账2个期权Token给用户
option.transfer(userAddress, 2 ether);
```

### 4. 行权期权

```solidity
// 用户在到期日行权1个期权Token
// 需要支付行权价格: 1 * 2000 = 2000 ETH
option.exerciseOptions{value: 2000 ether}(1 ether);
```

### 5. 销毁过期期权

```solidity
// 项目方在过期后销毁未行权的期权Token
option.destroyExpiredOptions();
```

## 🧪 测试用例

测试套件包含以下场景：

### 基础功能测试
- ✅ 合约初始化
- ✅ 期权发行
- ✅ 期权转账
- ✅ 期权行权
- ✅ 过期销毁

### 边界条件测试
- ✅ 无效参数处理
- ✅ 权限控制
- ✅ 时间限制
- ✅ 余额检查
- ✅ 支付验证

### 安全性测试
- ✅ 重入攻击防护
- ✅ 整数溢出保护
- ✅ 零地址检查
- ✅ 紧急提取功能

### Fuzz测试
- ✅ 随机金额发行
- ✅ 随机金额行权
- ✅ 边界值测试

## 📊 期权定价模型

### 内在价值计算

```solidity
function intrinsicValue(uint256 currentPrice) external view returns (uint256) {
    if (currentPrice > strikePrice) {
        return currentPrice - strikePrice;
    }
    return 0;
}
```

### 期权状态检查

```solidity
function canExercise() external view returns (bool) {
    return block.timestamp >= expirationTime && 
           block.timestamp <= expirationTime + 1 days && 
           !isExpired;
}
```

## 🔧 配置参数

### 默认配置

```solidity
// 测试环境配置
uint256 public constant STRIKE_PRICE = 2000 ether;     // 行权价格
uint256 public constant UNDERLYING_PRICE = 1800 ether; // 标的价格
uint256 public constant EXPIRATION_DAYS = 7;           // 到期天数
uint256 public constant EXERCISE_WINDOW = 1 days;      // 行权窗口期
```

### 自定义配置

可以根据需要调整以下参数：
- 行权价格 (strikePrice)
- 到期时间 (expirationTime)
- 标的价格 (underlyingPrice)
- 行权窗口期 (目前固定为1天)

## 🛡️ 安全考虑

### 已实现的安全措施

1. **重入攻击防护**: 所有外部调用使用nonReentrant修饰符
2. **安全转账**: 使用call方法替代transfer，避免gas限制
3. **权限控制**: 关键功能仅限合约所有者调用
4. **参数验证**: 构造函数和关键函数都有参数验证
5. **事件日志**: 完整的事件记录便于监控和审计
6. **错误处理**: 自定义错误类型提供清晰的错误信息

### 潜在风险

1. **价格操纵**: 依赖外部价格源，可能存在价格操纵风险
2. **流动性风险**: 期权Token的流动性依赖于市场需求
3. **智能合约风险**: 代码漏洞可能导致资金损失
4. **监管风险**: 期权交易可能面临监管限制

## 📈 使用场景

### 1. 投机交易
- 用户看涨ETH价格，购买看涨期权
- 如果ETH价格上涨超过行权价格，可以获得收益

### 2. 风险对冲
- ETH持有者可以卖出看涨期权获得权利金
- 为ETH持仓提供额外收益

### 3. 套利交易
- 在不同平台间进行期权套利
- 利用价格差异获得无风险收益

## 🔮 未来改进

### 计划中的功能

1. **看跌期权**: 添加看跌期权支持
2. **自动行权**: 在有利可图时自动行权
3. **期权链**: 支持多个行权价格和到期时间
4. **流动性挖矿**: 为期权提供者提供代币奖励
5. **价格预言机**: 集成Chainlink等价格预言机
6. **期权定价模型**: 实现Black-Scholes等定价模型

### 技术优化

1. **Gas优化**: 减少交易成本
2. **批量操作**: 支持批量行权和转账
3. **升级机制**: 实现合约升级功能
4. **多链部署**: 支持多个区块链网络

## 📞 联系方式

如有问题或建议，请通过以下方式联系：

- GitHub Issues: [项目地址]
- Email: [联系邮箱]
- Discord: [Discord频道]

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

**免责声明**: 本项目仅用于教育和研究目的。在生产环境中使用前，请进行充分的安全审计。投资有风险，请谨慎决策。