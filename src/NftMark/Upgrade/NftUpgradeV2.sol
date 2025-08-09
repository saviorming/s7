pragma solidity ^0.8.25;
import "./NftUpgradeV1.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title NftUpgradeV2
 * @dev 基于UUPS模式的可升级ERC721合约V2
 * 在V1基础上新增功能：暂停机制、批量铸造、单个NFT自定义URI
 */
contract NftUpgradeV2 is NftUpgradeV1, PausableUpgradeable {
     // ======== 新增状态变量（必须放在现有变量之后，保持存储布局兼容） ========
    mapping(uint256 => string) public tokenURIs;  // 单个NFT的自定义URI（覆盖baseURI）
    //  当自定义URI不存在时，是否回退到baseURI
    bool public uriFallbackToBase;

    // ======== 构造函数 ========
    /**
     * @dev 构造函数
     * 继续禁用初始化器（升级版本无需重新定义，但保持兼容性）
     */
    /// @custom:oz-upgrades-unsafe-allow-constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev V2版本初始化函数（升级后调用，仅执行一次）
     * 用于初始化V2新增的状态变量
     * @param _uriFallbackToBase 是否启用baseURI回退机制
     */
    function upgradeInitialize(bool _uriFallbackToBase) external reinitializer(2) {
        // 初始化PausableUpgradeable
        __Pausable_init();
        // 初始化新增变量
        uriFallbackToBase = _uriFallbackToBase;
    }

    // ======== V2新增功能 ========
    /**
     * @dev 批量铸造NFT（仅所有者）
     * @param to 接收者地址
     * @param count 铸造数量
     * @return 起始tokenId和结束tokenId
     */
    function mintBatch(address to, uint256 count) external onlyOwner whenNotPaused returns (uint256, uint256) {
        require(to != address(0), unicode"MyERC721V2: 接收者地址无效");
        require(count > 0, unicode"MyERC721V2: 铸造数量必须大于0");
        require(totalSupply + count <= maxSupply, unicode"MyERC721V2: 超出最大供应量");

        uint256 startTokenId = nextTokenId;
        uint256 endTokenId = nextTokenId + count - 1;

        // 批量铸造
        for (uint256 i = 0; i < count; i++) {
            _safeMint(to, nextTokenId);
            nextTokenId++;
            totalSupply++;
        }

        return (startTokenId, endTokenId);
    }

    /**
     * @dev 设置单个NFT的自定义URI（仅所有者）
     * @param tokenId NFT ID
     * @param customURI 自定义URI
     */
    function setTokenURI(uint256 tokenId, string memory customURI) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), unicode"MyERC721V2: NFT不存在");
        tokenURIs[tokenId] = customURI;
    }

    /**
     * @dev 获取NFT的URI（覆盖父合约）
     * 优先返回自定义URI，如果不存在且启用回退，则返回baseURI
     * @param tokenId NFT ID
     * @return NFT的URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), unicode"MyERC721V2: NFT不存在");
        
        string memory customURI = tokenURIs[tokenId];
        
        // 如果有自定义URI，直接返回
        if (bytes(customURI).length > 0) {
            return customURI;
        }
        
        // 如果启用回退机制，返回baseURI
        if (uriFallbackToBase) {
            return super.tokenURI(tokenId);
        }
        
        // 否则返回空字符串
        return "";
    }

    /**
     * @dev 暂停合约（仅所有者）
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev 恢复合约（仅所有者）
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev 覆盖mint函数，添加暂停检查
     */
    function mint(address to) external override onlyOwner whenNotPaused returns (uint256) {
        // 验证条件
        require(totalSupply < maxSupply, unicode"MyERC721V2: 已达到最大供应量");
        require(to != address(0), unicode"MyERC721V2: 接收者地址无效");

        // 铸造NFT
        uint256 tokenId = nextTokenId;
        _safeMint(to, tokenId);

        // 更新状态变量
        nextTokenId++;
        totalSupply++;

        return tokenId;
    }
}