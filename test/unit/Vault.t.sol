// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vault} from "../../src/Vault.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {IRebaseToken} from "../../src/interface/IRebaseToken.sol";

contract VaultTest is Test {
  Vault public vault;
  RebaseToken public rebaseToken;

  address public owner;
  address public user1;
  address public user2;
  address public attacker;

  // Constants
  uint256 constant INITIAL_DEPOSIT = 10 ether;
  uint256 constant INITIAL_INTEREST_RATE = 5e10;
  uint256 constant PRECISION_FACTOR = 1e18;

  event Deposited(address indexed user, uint256 amount);
  event Redeemed(address indexed user, uint256 amount);

  function setUp() public {
    owner = makeAddr("owner");
    user1 = makeAddr("user1");
    user2 = makeAddr("user2");
    attacker = makeAddr("attacker");

    // Create RebaseToken
    vm.prank(owner);
    rebaseToken = new RebaseToken();

    // Create Vault
    vault = new Vault(IRebaseToken(address(rebaseToken)));

    // Grant vault MINT_BURN_ROLE
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(address(vault));

    // Fund test accounts with ETH
    vm.deal(user1, 100 ether);
    vm.deal(user2, 100 ether);
    vm.deal(attacker, 100 ether);
  }

  // ============= Deposit Tests =============
  function test_DepositBasic() public {
    uint256 depositAmount = 1 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    assertEq(rebaseToken.principalBalanceOf(user1), depositAmount);
  }

  function test_DepositEmitsEvent() public {
    uint256 depositAmount = 1 ether;

    vm.expectEmit(true, true, true, true);
    emit Deposited(user1, depositAmount);

    vm.prank(user1);
    vault.deposit{value: depositAmount}();
  }

  function test_DepositZeroAmount() public {
    vm.prank(user1);
    vault.deposit{value: 0}();

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
  }

  function test_DepositMultipleTimes() public {
    uint256 deposit1 = 1 ether;
    uint256 deposit2 = 2 ether;
    uint256 deposit3 = 3 ether;

    vm.prank(user1);
    vault.deposit{value: deposit1}();

    vm.prank(user1);
    vault.deposit{value: deposit2}();

    vm.prank(user1);
    vault.deposit{value: deposit3}();

    assertEq(rebaseToken.principalBalanceOf(user1), deposit1 + deposit2 + deposit3);
  }

  function test_DepositMultipleUsers() public {
    uint256 deposit1 = 1 ether;
    uint256 deposit2 = 2 ether;

    vm.prank(user1);
    vault.deposit{value: deposit1}();

    vm.prank(user2);
    vault.deposit{value: deposit2}();

    assertEq(rebaseToken.principalBalanceOf(user1), deposit1);
    assertEq(rebaseToken.principalBalanceOf(user2), deposit2);
  }

  function test_DepositIncreaseVaultBalance() public {
    uint256 depositAmount = 5 ether;
    uint256 balanceBefore = address(vault).balance;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    uint256 balanceAfter = address(vault).balance;

    assertEq(balanceAfter - balanceBefore, depositAmount);
  }

  function test_DepositLargeAmount() public {
    uint256 largeAmount = 1000 ether;

    vm.deal(user1, largeAmount);

    vm.prank(user1);
    vault.deposit{value: largeAmount}();

    assertEq(rebaseToken.principalBalanceOf(user1), largeAmount);
  }

  function test_DepositMinimalAmount() public {
    uint256 minimalAmount = 1 wei;

    vm.prank(user1);
    vault.deposit{value: minimalAmount}();

    assertEq(rebaseToken.principalBalanceOf(user1), minimalAmount);
  }

  // ============= Redeem Tests =============
  function test_RedeemBasic() public {
    uint256 depositAmount = 2 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.prank(user1);
    vault.redeem(depositAmount);

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
  }

  function test_RedeemEmitsEvent() public {
    uint256 depositAmount = 2 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.expectEmit(true, true, true, true);
    emit Redeemed(user1, depositAmount);

    vm.prank(user1);
    vault.redeem(depositAmount);
  }

  function test_RedeemTransfersETH() public {
    uint256 depositAmount = 2 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    uint256 balanceBefore = user1.balance;

    vm.prank(user1);
    vault.redeem(depositAmount);

    uint256 balanceAfter = user1.balance;

    assertEq(balanceAfter - balanceBefore, depositAmount);
  }

  function test_RedeemPartialAmount() public {
    uint256 depositAmount = 4 ether;
    uint256 redeemAmount = 1 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.prank(user1);
    vault.redeem(redeemAmount);

    assertEq(rebaseToken.principalBalanceOf(user1), depositAmount - redeemAmount);
  }

  function test_RedeemMultipleTimes() public {
    uint256 depositAmount = 6 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.prank(user1);
    vault.redeem(2 ether);

    vm.prank(user1);
    vault.redeem(2 ether);

    vm.prank(user1);
    vault.redeem(2 ether);

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
  }

  function test_RedeemZeroAmount() public {
    uint256 depositAmount = 2 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.prank(user1);
    vault.redeem(0);

    assertEq(rebaseToken.principalBalanceOf(user1), depositAmount);
  }

  function test_RedeemMoreThanBalance() public {
    uint256 depositAmount = 2 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.expectRevert();
    vm.prank(user1);
    vault.redeem(5 ether);
  }

  function test_RedeemWithAccruedInterest() public {
    uint256 depositAmount = 10 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    // Simulate time passing for interest accrual
    vm.warp(block.timestamp + 100 days);

    uint256 balanceBefore = rebaseToken.balanceOf(user1);
    uint256 principalBefore = rebaseToken.principalBalanceOf(user1);

    // User redeems the principal amount
    vm.prank(user1);
    vault.redeem(principalBefore);

    // After redeem, the principal should be burned
    uint256 balanceAfter = rebaseToken.balanceOf(user1);
    assertLt(balanceAfter, balanceBefore);
  }

  function test_RedeemDecreaseVaultBalance() public {
    uint256 depositAmount = 5 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    uint256 vaultBalanceBefore = address(vault).balance;

    vm.prank(user1);
    vault.redeem(2 ether);

    uint256 vaultBalanceAfter = address(vault).balance;

    assertEq(vaultBalanceBefore - vaultBalanceAfter, 2 ether);
  }

  function test_RedeemMinimalAmount() public {
    uint256 depositAmount = 2 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.prank(user1);
    vault.redeem(1 wei);

    assertEq(rebaseToken.principalBalanceOf(user1), depositAmount - 1 wei);
  }

  // ============= Integration Tests =============
  function test_DepositAndRedeemCycle() public {
    uint256 depositAmount = 5 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    assertEq(rebaseToken.principalBalanceOf(user1), depositAmount);
    assertEq(address(vault).balance, depositAmount);

    vm.prank(user1);
    vault.redeem(depositAmount);

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
    assertEq(address(vault).balance, 0);
  }

  function test_MultipleUsersDepositAndRedeem() public {
    uint256 deposit1 = 3 ether;
    uint256 deposit2 = 7 ether;

    vm.prank(user1);
    vault.deposit{value: deposit1}();

    vm.prank(user2);
    vault.deposit{value: deposit2}();

    assertEq(address(vault).balance, deposit1 + deposit2);

    vm.prank(user1);
    vault.redeem(deposit1);

    assertEq(address(vault).balance, deposit2);
    assertEq(rebaseToken.principalBalanceOf(user1), 0);
    assertEq(rebaseToken.principalBalanceOf(user2), deposit2);
  }

  function test_DepositRedeemTransferCycle() public {
    uint256 depositAmount = 10 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    // Transfer some tokens to user2
    vm.prank(user1);
    rebaseToken.transfer(user2, 3 ether);

    assertEq(rebaseToken.principalBalanceOf(user1), 7 ether);
    assertEq(rebaseToken.principalBalanceOf(user2), 3 ether);

    // User2 can redeem their tokens
    vm.prank(user2);
    vault.redeem(3 ether);

    assertEq(rebaseToken.principalBalanceOf(user2), 0);
  }

  function test_DepositWithInterestRateDecreases() public {
    uint256 depositAmount = 10 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.warp(block.timestamp + 100 days);

    uint256 balanceDay100 = rebaseToken.balanceOf(user1);

    // Owner decreases interest rate
    vm.prank(owner);
    rebaseToken.setInterestRate(2e10);

    vm.warp(block.timestamp + 100 days);

    uint256 balanceDay200 = rebaseToken.balanceOf(user1);

    // Balance should still grow, but slower
    assert(balanceDay200 > balanceDay100);
  }

  function test_RedeemAfterInterestAccrual() public {
    uint256 depositAmount = 10 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    // Time passes and interest accrues
    vm.warp(block.timestamp + 100 days);

    uint256 principalBalance = rebaseToken.principalBalanceOf(user1);
    uint256 totalBalance = rebaseToken.balanceOf(user1);

    // Principal balance should remain the same
    assertEq(principalBalance, depositAmount);

    // Total balance should be greater due to accrued interest
    assertGt(totalBalance, principalBalance);

    // Redeem just the principal
    vm.prank(user1);
    vault.redeem(principalBalance);

    // All tokens including principal should be burned from the account
    uint256 finalBalance = rebaseToken.balanceOf(user1);
    assertLt(finalBalance, totalBalance);
  }

  // ============= Getter Tests =============
  function test_GetRebaseToken() public {
    assertEq(vault.getRebaseToken(), address(rebaseToken));
  }

  // ============= Receive Function Tests =============
  function test_ReceiveEtherDirectly() public {
    uint256 sendAmount = 5 ether;

    vm.prank(user1);
    (bool success,) = payable(address(vault)).call{value: sendAmount}("");

    assertTrue(success);
    assertEq(address(vault).balance, sendAmount);
  }

  function test_SendEtherWithNoData() public {
    uint256 sendAmount = 2 ether;

    vm.prank(user1);
    address(vault).call{value: sendAmount}("");

    assertEq(address(vault).balance, sendAmount);
  }

  // ============= Edge Cases & Security Tests =============
  function test_RedeemWithoutDeposit() public {
    vm.expectRevert();
    vm.prank(user1);
    vault.redeem(1 ether);
  }

  function test_RedeemFromDifferentUser() public {
    uint256 depositAmount = 5 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    // user2 tries to redeem user1's tokens
    vm.expectRevert();
    vm.prank(user2);
    vault.redeem(depositAmount);
  }

  function test_VaultBalance() public {
    uint256 totalDeposits = 0;

    for (uint256 i = 0; i < 5; i++) {
      address user = makeAddr(string(abi.encodePacked("user", i)));
      vm.deal(user, 100 ether);

      uint256 depositAmount = (i + 1) * 1 ether;
      vm.prank(user);
      vault.deposit{value: depositAmount}();

      totalDeposits += depositAmount;
    }

    assertEq(address(vault).balance, totalDeposits);
  }

  function test_ConsistencyAfterMultipleOperations() public {
    // Series of operations
    vm.prank(user1);
    vault.deposit{value: 10 ether}();

    vm.prank(user2);
    vault.deposit{value: 20 ether}();

    assertEq(address(vault).balance, 30 ether);

    vm.prank(user1);
    vault.redeem(5 ether);

    assertEq(address(vault).balance, 25 ether);

    vm.prank(user2);
    vault.redeem(10 ether);

    assertEq(address(vault).balance, 15 ether);
  }

  function test_DepositAndRedeemSameBlock() public {
    uint256 depositAmount = 5 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    vm.prank(user1);
    vault.redeem(depositAmount);

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
    assertEq(address(vault).balance, 0);
  }

  function test_RapidDepositRedeem() public {
    uint256 amount = 1 ether;

    for (uint256 i = 0; i < 10; i++) {
      vm.prank(user1);
      vault.deposit{value: amount}();

      vm.prank(user1);
      vault.redeem(amount);
    }

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
  }

  function test_VaultCanReceiveETHFromMultipleSources() public {
    uint256 deposit = 5 ether;
    uint256 directSend = 3 ether;

    vm.prank(user1);
    vault.deposit{value: deposit}();

    vm.prank(user2);
    (bool success,) = payable(address(vault)).call{value: directSend}("");
    assertTrue(success);

    assertEq(address(vault).balance, deposit + directSend);
  }

  function test_RedeemBurnsBurnTokens() public {
    uint256 depositAmount = 5 ether;

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    uint256 totalSupplyBefore = rebaseToken.totalSupply();

    vm.prank(user1);
    vault.redeem(depositAmount);

    uint256 totalSupplyAfter = rebaseToken.totalSupply();

    assertEq(totalSupplyBefore - totalSupplyAfter, depositAmount);
  }

  function test_DepositMintsTokens() public {
    uint256 depositAmount = 5 ether;

    uint256 totalSupplyBefore = rebaseToken.totalSupply();

    vm.prank(user1);
    vault.deposit{value: depositAmount}();

    uint256 totalSupplyAfter = rebaseToken.totalSupply();

    assertEq(totalSupplyAfter - totalSupplyBefore, depositAmount);
  }
}
