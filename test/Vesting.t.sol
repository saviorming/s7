// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "../src/Defi/release/Vesting.sol";

contract VestingTest is Test {
    ReleaseToken public token;
    Vesting public vesting;
    
    address public owner = address(this);
    address public beneficiary = address(0x123);
    
    uint256 public constant CLIFF_DAYS = 365; // 12个月 = 365天
    uint256 public constant VESTING_DAYS = 30; // 每月30天（未使用）
    uint256 public constant DURATION_DAYS = 730; // 24个月 = 730天
    uint256 public constant TOTAL_AMOUNT = 1_000_000 * 10**18;
    
    function setUp() public {
        // 部署代币合约
        token = new ReleaseToken();
        
        // 部署vesting合约
        vesting = new Vesting(
            address(token),
            uint64(DURATION_DAYS), // duration参数（未使用）
            beneficiary,
            CLIFF_DAYS,
            VESTING_DAYS,
            DURATION_DAYS
        );
        
        // 授权并初始化代币转移
        token.approve(address(vesting), TOTAL_AMOUNT);
        vesting.initializeTokens();
        
        // 验证初始状态
        assertEq(vesting._beneficiary(), beneficiary);
        assertEq(address(vesting._releaseToken()), address(token));
        assertEq(vesting._totalVestingAmount(), TOTAL_AMOUNT);
        assertEq(vesting._released(), 0);
    }
    
    function testInitialState() public {
        // 检查初始状态
        assertEq(vesting.remaining(), TOTAL_AMOUNT);
        assertEq(vesting.releasable(), 0); // 锁定期内不能释放
        
        // 检查合约信息
        (
            address _beneficiary,
            address _token,
            uint256 _start,
            uint256 _cliffDays,
            uint256 _durationDays,
            uint256 _totalAmount,
            uint256 _released,
            uint256 _releasableNow
        ) = vesting.getVestingInfo();
        
        assertEq(_beneficiary, beneficiary);
        assertEq(_token, address(token));
        assertEq(_cliffDays, CLIFF_DAYS);
        assertEq(_durationDays, DURATION_DAYS);
        assertEq(_totalAmount, TOTAL_AMOUNT);
        assertEq(_released, 0);
        assertEq(_releasableNow, 0);
    }
    
    function testCliffPeriod() public {
        // 在锁定期内，不应该有任何代币可以释放
        
        // 跳转到锁定期中间（6个月）
        vm.warp(block.timestamp + 180 days);
        assertEq(vesting.releasable(), 0);
        
        // 跳转到锁定期末尾前一天
        vm.warp(block.timestamp + 184 days); // 总共364天
        assertEq(vesting.releasable(), 0);
        
        // 尝试释放应该失败
        vm.prank(beneficiary);
        vm.expectRevert("No tokens available to release");
        vesting.release();
    }
    
    function testLinearVesting() public {
        // 跳转到锁定期结束后（第13个月开始）
        vm.warp(block.timestamp + CLIFF_DAYS * 1 days + 1);
        
        // 此时应该有少量代币可以释放
        uint256 releasable1 = vesting.releasable();
        assertGt(releasable1, 0);
        assertLt(releasable1, TOTAL_AMOUNT);
        
        // 跳转到释放期中间（第25个月，即锁定期后12个月）
        vm.warp(block.timestamp + 365 days); // 再过12个月
        
        uint256 releasable2 = vesting.releasable();
        assertGt(releasable2, releasable1);
        
        // 应该大约释放50%的代币（12/24个月）
        uint256 expectedHalf = TOTAL_AMOUNT / 2;
        uint256 tolerance = TOTAL_AMOUNT / 100; // 1%容差
        assertApproxEqAbs(releasable2, expectedHalf, tolerance);
    }
    
    function testFullVesting() public {
        // 跳转到完全释放期（36个月后）
        vm.warp(block.timestamp + (CLIFF_DAYS + DURATION_DAYS) * 1 days + 1);
        
        // 所有代币都应该可以释放
        assertEq(vesting.releasable(), TOTAL_AMOUNT);
        assertEq(vesting.remaining(), TOTAL_AMOUNT);
    }
    
    function testRelease() public {
        // 跳转到可以释放的时间
        vm.warp(block.timestamp + CLIFF_DAYS * 1 days + 30 days); // 锁定期后1个月
        
        uint256 releasableAmount = vesting.releasable();
        assertGt(releasableAmount, 0);
        
        uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary);
        
        // 受益人释放代币
        vm.prank(beneficiary);
        vm.expectEmit(true, false, false, true);
        emit Vesting.TokensReleased(beneficiary, releasableAmount);
        vesting.release();
        
        // 检查余额变化
        assertEq(token.balanceOf(beneficiary), beneficiaryBalanceBefore + releasableAmount);
        assertEq(vesting._released(), releasableAmount);
        assertEq(vesting.releasable(), 0); // 当前可释放应该为0
        assertEq(vesting.remaining(), TOTAL_AMOUNT - releasableAmount);
    }
    
    function testOwnerCanRelease() public {
        // 跳转到可以释放的时间
        vm.warp(block.timestamp + CLIFF_DAYS * 1 days + 30 days);
        
        uint256 releasableAmount = vesting.releasable();
        assertGt(releasableAmount, 0);
        
        // 所有者也可以触发释放
        vm.prank(owner);
        vesting.release();
        
        assertEq(token.balanceOf(beneficiary), releasableAmount);
    }
    
    function testUnauthorizedRelease() public {
        vm.warp(block.timestamp + CLIFF_DAYS * 1 days + 30 days);
        
        // 非授权用户不能释放
        vm.prank(address(0x456));
        vm.expectRevert("Only beneficiary or owner can release");
        vesting.release();
    }
    
    function testMultipleReleases() public {
        // 第一次释放
        vm.warp(block.timestamp + CLIFF_DAYS * 1 days + 30 days);
        uint256 firstRelease = vesting.releasable();
        
        vm.prank(beneficiary);
        vesting.release();
        
        // 第二次释放
        vm.warp(block.timestamp + 30 days); // 再过1个月
        uint256 secondRelease = vesting.releasable();
        assertGt(secondRelease, 0);
        
        vm.prank(beneficiary);
        vesting.release();
        
        // 检查总释放量
        assertEq(vesting._released(), firstRelease + secondRelease);
        assertEq(token.balanceOf(beneficiary), firstRelease + secondRelease);
    }
    
    function testRevoke() public {
        // 跳转到释放期中间
        vm.warp(block.timestamp + CLIFF_DAYS * 1 days + 365 days);
        
        // 先释放一部分
        vm.prank(beneficiary);
        vesting.release();
        
        uint256 releasedAmount = vesting._released();
        uint256 remainingAmount = vesting.remaining();
        uint256 ownerBalanceBefore = token.balanceOf(owner);
        
        // 所有者撤销剩余代币
        vm.expectEmit(true, false, false, true);
        emit Vesting.VestingRevoked(beneficiary, remainingAmount);
        vesting.revoke();
        
        // 检查状态
        assertEq(vesting._released(), TOTAL_AMOUNT); // 标记为全部已释放
        assertEq(vesting.remaining(), 0);
        assertEq(vesting.releasable(), 0);
        assertEq(token.balanceOf(owner), ownerBalanceBefore + remainingAmount);
        
        // 撤销后不能再释放
        vm.prank(beneficiary);
        vm.expectRevert("No tokens available to release");
        vesting.release();
    }
    
    function testRevokeUnauthorized() public {
        vm.prank(beneficiary);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", beneficiary));
        vesting.revoke();
    }
    
    function testRevokeWhenNothingToRevoke() public {
        // 跳转到完全释放后
        vm.warp(block.timestamp + (CLIFF_DAYS + DURATION_DAYS) * 1 days + 1);
        
        // 释放所有代币
        vm.prank(beneficiary);
        vesting.release();
        
        // 尝试撤销应该失败
        vm.expectRevert("No tokens to revoke");
        vesting.revoke();
    }
    
    function testVestingScheduleAccuracy() public {
        // 测试不同时间点的释放精度
        uint256[] memory testMonths = new uint256[](5);
        testMonths[0] = 1;  // 第1个月
        testMonths[1] = 6;  // 第6个月
        testMonths[2] = 12; // 第12个月
        testMonths[3] = 18; // 第18个月
        testMonths[4] = 24; // 第24个月
        
        uint256 startTime = block.timestamp;
        
        for (uint256 i = 0; i < testMonths.length; i++) {
            uint256 months = testMonths[i];
            uint256 timeOffset = (months * DURATION_DAYS * 1 days) / 24;
            // 从初始时间开始计算，而不是累积时间
            vm.warp(startTime + CLIFF_DAYS * 1 days + timeOffset);
            
            uint256 expectedVested;
            if (months >= 24) {
                expectedVested = TOTAL_AMOUNT; // 完全释放
            } else {
                expectedVested = (TOTAL_AMOUNT * months) / 24; // 线性释放
            }
            
            uint256 actualVested = vesting.releasable() + vesting._released();
            uint256 tolerance = TOTAL_AMOUNT / 1000; // 0.1%容差
            
            assertApproxEqAbs(actualVested, expectedVested, tolerance, 
                string(abi.encodePacked("Month ", vm.toString(months), " vesting mismatch")));
        }
    }
    
    function testGetVestingInfo() public {
        vm.warp(block.timestamp + CLIFF_DAYS * 1 days + 365 days);
        
        (
            address _beneficiary,
            address _token,
            uint256 _start,
            uint256 _cliffDays,
            uint256 _durationDays,
            uint256 _totalAmount,
            uint256 _released,
            uint256 _releasableNow
        ) = vesting.getVestingInfo();
        
        assertEq(_beneficiary, beneficiary);
        assertEq(_token, address(token));
        assertEq(_cliffDays, CLIFF_DAYS);
        assertEq(_durationDays, DURATION_DAYS);
        assertEq(_totalAmount, TOTAL_AMOUNT);
        assertEq(_released, 0); // 还没有释放
        assertGt(_releasableNow, 0); // 应该有可释放的代币
    }
}