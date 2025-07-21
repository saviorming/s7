pragma solidity ^0.8.25;

import "forge-std/console.sol";


contract Bank{
    address public owner;
    mapping(address => uint) public balances;
    address[3] public top;

    constructor(address _owner) {
        owner = _owner;
        console.log("current contract owner:",owner);
    }

          // 事件记录
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed admin, uint256 amount);

    modifier onlyAdmin{
        require(msg.sender==owner,"only admin can withdraw~!");
        _;
    }

    receive() external payable{
        deposit();
    }

    function deposit() public payable{
        require(msg.value>0,"amount must be greater than 0");
        balances[msg.sender] += msg.value;
          // 更新前三名存款人
        _updateTopDepositors(msg.sender);
        emit Deposited(msg.sender,msg.value);
    } 

    function withdraw(uint256 amount) public onlyAdmin{
        require(amount <= address(this).balance,"Insufficient amount!");
        payable(owner).transfer(amount);
        emit Withdrawn(owner, amount);
    }

    function _updateTopDepositors(address depositor) public{
        uint256 amount = balances[depositor];
        for(uint i=0;i<3;i++){
            if (top[i] == depositor || amount <= balances[top[i]]) {
                continue;
            }

            for(uint j = 2; j > i; j--){
                top[j] = top[j-1];
            }
            top[i] = depositor;
            break;
        }
                // 确保顺序正确（单次冒泡）
        for (uint i = 0; i < 2; i++) {
            if (balances[top[i]] < balances[top[i+1]]) {
                (top[i], top[i+1]) = (top[i+1], top[i]);
            }
        }
    }

    function getTop() public view returns(address[3] memory){
        return top;
    }


}