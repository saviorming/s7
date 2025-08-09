pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";


/**
 * @title MyERC721V1
 * @dev 基于UUPS模式的可升级ERC721合约V1
 * 解决了多重继承中的函数签名冲突问题
 */
contract NftUpgradeV1 is ERC721Upgradeable,UUPSUpgradeable,OwnableUpgradeable{
    // 状态变量 - 存储在代理合约中
    string public baseURI;          // NFT元数据基础URI
    uint256 public totalSupply;     // 已铸造总量
    uint256 public maxSupply;       // 最大供应量
    uint256 public nextTokenId;     // 下一个待铸造的tokenId
    
    //保证只初始化一次
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数 - 替代构造函数完成初始化
     * @param name NFT集合名称
     * @param symbol NFT集合符号
     * @param baseURI_ 元数据基础URI
     * @param _maxSupply 最大可铸造数量
     * @param initialOwner 初始所有者地址
     */
    function initialize(
        string memory name,
        string memory symbol,
        string memory baseURI_,
        uint256 _maxSupply,
        address initialOwner  // 新增：初始所有者参数
    ) external initializer {
        // 初始化父合约（必须按顺序调用）
        __ERC165_init();                  // 初始化ERC165接口检测
        __ERC721_init(name, symbol);      // 初始化ERC721基础功能
        __Ownable_init(initialOwner);     // 初始化所有权（指定初始所有者）
        __UUPSUpgradeable_init();         // 初始化UUPS升级机制
        // 初始化自定义状态变量
        baseURI = baseURI_;
        maxSupply = _maxSupply;
        nextTokenId = 1; // 从1开始铸造
        totalSupply = 0;
    }

    // ======== 核心功能 ========
    /**
     * @dev 铸造新NFT（仅所有者）
     * @param to 接收者地址
     * @return 铸造的tokenId
     */
    function mint(address to) external virtual onlyOwner returns (uint256) {
        // 验证条件
        require(totalSupply < maxSupply, unicode"MyERC721: 已达到最大供应量");
        require(to != address(0), unicode"MyERC721: 接收者地址无效");

        // 铸造NFT
        uint256 tokenId = nextTokenId;
        _safeMint(to, tokenId);

        // 更新状态变量
        nextTokenId++;
        totalSupply++;

        return tokenId;
    }

        // ======== 重写函数（解决继承冲突） ========
    /**
     * @dev 重写_baseURI函数，返回自定义baseURI
     * ERC721标准会自动拼接为 tokenURI = baseURI + tokenId.toString()
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

        // ======== UUPS升级控制 ========
    /**
     * @dev 控制升级权限（仅所有者可升级）
     * @param newImplementation 新逻辑合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
