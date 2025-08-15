pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RebaseToken is ERC20, Ownable {
// =============================================================
//                           常量定义
// =============================================================
    //时间常量 365天
    uint256 public constant YEAR_IN_SECONDS = 365 days;
    //通缩率 1%
    uint256 public constant DEFLATION_RATE = 1;
    //初始总供应量：1亿（18位小数）
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18;

    // =============================================================
    //                           状态变量
    // =============================================================
    // 通缩 rebase次数
    uint256 public rebaseCount;
    // 最后的rebase时间，初始化时候等于当天时间，后续每次rebase都更新为当前时间
    uint256 public lastRebaseTimestamp;
    // @notice 当前实际流通总量（动态变化，重基时更新）
    uint256 private _currentCirculatingSupply;
    // 记录每次重基时的总供应量
    mapping(uint256 => uint256) public supplyAtRebase;

    // 内部缩放余额（总量固定） - 记录每个地址的基础份额
    mapping(address => uint256) private _scaledBalances;

    // =============================================================
    //                           事件定义
    // =============================================================

    /// @notice 记录重基操作详情
    /// @param rebaseId 重基次数ID
    /// @param newTotalSupply 重基后的实际流通量
    /// @param timestamp 重基发生的时间戳
    event Rebase(uint256 indexed rebaseId, uint256 newTotalSupply, uint256 timestamp);

    constructor() 
    ERC20("DeflationaryRebaseToken", "DRT") Ownable(msg.sender){
        // 初始基础份额全部分配给部署者
        _scaledBalances[msg.sender] = INITIAL_SUPPLY;
        _currentCirculatingSupply = INITIAL_SUPPLY;
        // 记录第0次重基（初始状态）的流通量
        supplyAtRebase[0] = INITIAL_SUPPLY;
        //初始化最后重基时间为合约部署时间
        lastRebaseTimestamp = block.timestamp;
        // 触发初始 mint 事件（从0地址到部署者）
        emit Transfer(address(0), msg.sender, INITIAL_SUPPLY);
    }

    // 缩放因子：当前总供应量 / 初始总供应量（以1e18为基数）
    function scalingFactor() public view returns (uint256) {
        return _currentCirculatingSupply * 1e18 / INITIAL_SUPPLY;
    }

    function rebase() external onlyOwner(){
        // 验证重基条件：距离上次重基至少1年
        require(
            block.timestamp >= lastRebaseTimestamp + YEAR_IN_SECONDS,
            "DeflationaryRebaseToken: rebase not yet available"
        );
        //计算新的实际流通量（通缩1%，即保留99%）
        uint256 newCirculatingSupply = _currentCirculatingSupply * (100 - DEFLATION_RATE) / 100;
        _currentCirculatingSupply = newCirculatingSupply;
        // 更新重基计数器
        rebaseCount++;
        supplyAtRebase[rebaseCount] = newCirculatingSupply;
        // 更新最后重基时间
        lastRebaseTimestamp = block.timestamp;
         // 触发重基事件
        emit Rebase(rebaseCount, newCirculatingSupply, block.timestamp);
    }


    // =============================================================
    //                       ERC20 接口重写
    // =============================================================

    /**
     * @notice 重写ERC20的totalSupply，返回固定的基础总供应量
     * @return 基础总供应量（固定值）
     */
    function totalSupply() public view override returns (uint256) {
        return INITIAL_SUPPLY;
    }

    /**
     * @notice 返回当前实际流通量（动态变化）
     * @return 当前实际流通的代币数量
     */
    function currentCirculatingSupply() public view returns (uint256) {
        return _currentCirculatingSupply;
    }

    
    /**
     * @notice 重写ERC20的balanceOf，返回用户实际可支配的代币数量
     * @param account 要查询的地址
     * @return 实际可支配的代币数量
     */
     function balanceOf(address account) public view override returns (uint256) {
         uint256 factor = scalingFactor();
        return _scaledBalances[account] * factor / 1e18;
    }

        /**
     * @notice 查询用户的基础份额余额（内部记账单位）
     * @param account 要查询的地址
     * @return 基础份额数量
     */
    function scaledBalanceOf(address account) public view returns (uint256) {
        return _scaledBalances[account];
    }

        // =============================================================
    //                        转账逻辑
    // =============================================================

    /**
     * @notice 重写转账函数，基于基础份额进行转移
     * @param to 接收地址
     * @param amount 要转账的实际代币数量（用户视角）
     * @return 转账是否成功
     */
     function transfer(address to,uint256 amount)public override returns(bool){
        require(to != address(0), "Defi: transfer to the zero address");
        require(amount > 0, "Defi: transfer amount must be greater than 0");
        uint256 factor = scalingFactor();
        //算出实际金额中的占比
        uint256 scaledAmount = (amount * 1e18) / factor;
        require(_scaledBalances[msg.sender] >= scaledAmount, "Defi: transfer amount exceeds balance");
        // 执行转账
        _scaledBalances[msg.sender] -= scaledAmount;
        _scaledBalances[to] += scaledAmount;
        emit Transfer(msg.sender, to, amount);
        return true;
     }

    function transferFrom(address from,address to,uint256 amount)public override returns (bool){
        require(from != address(0), "Defi: transfer from the zero address");
        require(to != address(0), "Defi: transfer to the zero address");
        require(amount > 0, "Defi: transfer amount must be greater than 0");
        uint256 factor = scalingFactor();
        //算出实际金额中的占比
        uint256 scaledAmount = (amount * 1e18) / factor;
        //验证授权
        require(allowance(from,msg.sender)>= amount, "DeflationaryRebaseToken: allowance exceeded");
        require(_scaledBalances[from] >= scaledAmount, "Defi: transfer amount exceeds balance");
        // 执行转账
        _scaledBalances[from] -= scaledAmount;
        _scaledBalances[to] += scaledAmount;
        // 更新授权额度
        _approve(from, msg.sender, allowance(from, msg.sender) - amount);
        emit Transfer(from, to, amount);
        return true;
    }

    /**
     * @notice 重写approve函数，确保授权基于实际代币数量
     * @param spender 被授权地址
     * @param amount 授权的实际代币数量
     * @return 授权是否成功
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice 增加授权额度
     * @param spender 被授权地址
     * @param addedValue 增加的授权数量
     * @return 操作是否成功
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, allowance(msg.sender, spender) + addedValue);
        return true;
    }

    /**
     * @notice 减少授权额度
     * @param spender 被授权地址
     * @param subtractedValue 减少的授权数量
     * @return 操作是否成功
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = allowance(msg.sender, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }


    
}
