// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interface/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();

        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintBurnRole(address(vault)); // allow vault to mint and burn tokens

        vm.stopPrank();

    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function test_DepositLinear(uint256 amount) public {

        amount = bound(amount, 1e5, type(uint96).max);

        // 1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount); // Give user some ETH

        vault.deposit{value: amount}();

        // 2 Check the rebase token balance of the user
        uint256 startingBalance = rebaseToken.balanceOf(user);
        assertEq(startingBalance, amount, "User should have minted RebaseTokens equal to the deposited ETH");

        // 3. Warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        assertGt(middleBalance, startingBalance, "User's RebaseToken balance should have increased due to interest accrual");

        // 4. warp the time again and check the balance
        vm.warp(block.timestamp + 1 hours);
        uint256 endingBalance = rebaseToken.balanceOf(user);
        assertGt(endingBalance, middleBalance, "User's RebaseToken balance should have increased again due to interest accrual");

        // the diffference is 1, why?
        assertApproxEqAbs(endingBalance - middleBalance, middleBalance - startingBalance, 1);
        vm.stopPrank();
    }

    function test_RedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);

        // 1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount); // Give user some ETH

        vault.deposit{value: amount}();

        // 2 Check the rebase token balance of the user
        uint256 startingBalance = rebaseToken.balanceOf(user);
        assertEq(startingBalance, amount, "User should have minted RebaseTokens equal to the deposited ETH");

        // 3. Redeem straight away
        vault.redeem(type(uint256).max); // Redeem all RebaseTokens

        // 4. Check the balance again
        uint256 endingBalance = rebaseToken.balanceOf(user);
        assertEq(endingBalance, 0, "User's RebaseToken balance should be zero after redeeming all tokens");

        assertEq(address(user).balance, amount, "User should have received back the full amount of ETH");
        vm.stopPrank();
    }

    function test_RedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {

        time = bound(time, 1000, type(uint96).max);
        depositAmount = bound(depositAmount, 1e5, type(uint96).max);

        // 1. Deposit
        vm.deal(user, depositAmount); // Give user some ETH
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // 2 Warp the time
        vm.warp(block.timestamp + time); 
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);
        
        vm.deal(owner, balanceAfterSomeTime - depositAmount); // Give owner some ETH to add rewards
        vm.prank(owner); // Owner can add rewards to the vault
        addRewardsToVault( balanceAfterSomeTime - depositAmount); // Add rewards to the vault to simulate interest accrual

        // 3. Redeem all RebaseTokens
        vm.prank(user); // User redeems their tokens
        vault.redeem(type(uint256).max); // Redeem all RebaseTokens
        

        // 4. Check the balance again
        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balanceAfterSomeTime, "User should have received back the full amount of ETH");
        assertGt(ethBalance, depositAmount, "User should have received more ETH than deposited due to interest accrual");
    }

    function test_Tranfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // 1. Deposit
        
        vm.deal(user, amount); // Give user some ETH
        vm.prank(user);
        vault.deposit{value: amount}();

       address user2 = makeAddr("user2");
       
       uint256 userBalance = rebaseToken.balanceOf(user);
       uint256 user2Balance = rebaseToken.balanceOf(user2);

       assertEq(userBalance, amount, "User should have minted RebaseTokens equal to the deposited ETH");
       assertEq(user2Balance, 0, "User2 should have zero RebaseTokens at the start"); 

         // 2. Transfer some RebaseTokens to user2
         vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);

        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);   

        assertEq(userBalanceAfterTransfer, amount - amountToSend, "User's RebaseToken balance should be reduced by the transferred amount");
        assertEq(user2BalanceAfterTransfer, amountToSend, "User2's RebaseToken balance should be equal to the transferred amount");

        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10); 
    }
    

     function test_SetInterestRate(uint256 newInterestRate) public {
        uint256 initialInterestRate = rebaseToken.getInterestRate();
        newInterestRate = bound(newInterestRate, 1e10, initialInterestRate -1); 
        vm.prank(owner);
        rebaseToken.setInterestRate(newInterestRate); 

        uint256 newRate = rebaseToken.getInterestRate();
        assertLt(rebaseToken.getInterestRate(), initialInterestRate, "Interest rate should be updated to a lower value");
        assertEq(rebaseToken.getInterestRate(), newInterestRate, "Interest rate should be updated to the new value");
    }

    function test_SetInterestRateShouldRevertIfNotOwner() public {
        
       
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        vm.prank(user);
        rebaseToken.setInterestRate(4e10); // User tries to set interest rate, should rever
      
    }

    function test_SetInterestRateShouldRevertIfGreaterThanCurrentRate() public {
        uint256 currentRate = rebaseToken.getInterestRate();
        uint256 newRate = currentRate + 1e10; // New rate is greater than current rate

        vm.expectRevert(
    abi.encodeWithSelector(
        RebaseToken.RebaseToken__InterestRateCanOnlyBeDecreased.selector,
        newRate,
        currentRate
    )
);
        vm.prank(owner);
        rebaseToken.setInterestRate(newRate); 
    }

    
        
        
}