# TokenBank DApp

这是一个基于 Viem 和 Next.js 构建的 TokenBank 去中心化应用前端界面。

## 功能特性

- 🔗 **钱包连接**: 支持 MetaMask 等主流钱包
- 💰 **余额显示**: 实时显示钱包中的 Token 余额
- 📥 **存款功能**: 将 Token 存入 TokenBank 合约
- 📤 **取款功能**: 从 TokenBank 合约中取出 Token
- 🔄 **实时更新**: 自动刷新余额和存款信息
- 🎨 **现代化UI**: 响应式设计，支持移动端

## 技术栈

- **前端框架**: Next.js 14 + React 18
- **区块链交互**: Viem + Wagmi
- **钱包连接**: RainbowKit
- **样式**: Tailwind CSS
- **图标**: Lucide React
- **类型安全**: TypeScript

## 快速开始

### 1. 安装依赖

\`\`\`bash
cd frontend
npm install
\`\`\`

### 2. 配置合约地址

编辑 \`lib/config.ts\` 文件，更新合约地址：

\`\`\`typescript
export const CONTRACT_ADDRESSES = {
  TOKEN_BANK: '0x你的TokenBank合约地址',
  BASE_ERC20: '0x你的ERC20代币合约地址',
}
\`\`\`

### 3. 启动开发服务器

\`\`\`bash
npm run dev
\`\`\`

应用将在 \`http://localhost:3000\` 启动。

## 使用说明

### 连接钱包
1. 点击"Connect Wallet"按钮
2. 选择您的钱包（推荐 MetaMask）
3. 确认连接

### 存款流程
1. 在存款区域输入要存入的 Token 数量
2. 首次存款需要先点击"授权Token"按钮
3. 确认授权交易
4. 点击"存款"按钮
5. 确认存款交易

### 取款流程
1. 在取款区域输入要取出的 Token 数量
2. 点击"取款"按钮
3. 确认取款交易

## 合约部署

在使用前端之前，您需要先部署合约：

### 1. 部署 BaseERC20 合约
\`\`\`bash
cd ..  # 回到项目根目录
forge create src/ERC20Token/BaseERC20.sol:BaseERC20 --private-key YOUR_PRIVATE_KEY --rpc-url YOUR_RPC_URL
\`\`\`

### 2. 部署 TokenBank 合约
\`\`\`bash
forge create src/ERC20Token/TokenBank.sol:TokenBank --constructor-args YOUR_ERC20_ADDRESS --private-key YOUR_PRIVATE_KEY --rpc-url YOUR_RPC_URL
\`\`\`

### 3. 更新前端配置
将部署得到的合约地址更新到 \`lib/config.ts\` 中。

## 网络配置

默认支持以下网络：
- Mainnet (主网)
- Sepolia (测试网)
- Hardhat (本地测试网)

如需添加其他网络，请修改 \`lib/config.ts\` 中的配置。

## 故障排除

### 常见问题

1. **钱包连接失败**
   - 确保已安装 MetaMask 或其他支持的钱包
   - 检查网络是否正确

2. **交易失败**
   - 确保钱包中有足够的 ETH 支付 Gas 费
   - 检查合约地址是否正确
   - 确认网络配置正确

3. **余额不更新**
   - 点击刷新按钮手动更新
   - 检查网络连接

## 开发

### 项目结构
\`\`\`
frontend/
├── app/                 # Next.js App Router
│   ├── globals.css     # 全局样式
│   ├── layout.tsx      # 根布局
│   └── page.tsx        # 主页
├── components/         # React 组件
│   ├── Providers.tsx   # 钱包和查询提供者
│   └── TokenBankInterface.tsx  # 主界面组件
├── lib/               # 工具库
│   └── config.ts      # Wagmi 和合约配置
└── package.json       # 依赖配置
\`\`\`

### 自定义样式
主要样式定义在 \`app/globals.css\` 中，使用 Tailwind CSS 类进行样式设计。

## 许可证

MIT License