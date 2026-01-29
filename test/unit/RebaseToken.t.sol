// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";

contract RebaseTokenTest is Test {
  RebaseToken public rebaseToken;
  address public owner;
  address public minter;
  address public user1;
  address public user2;

  // Constants
  uint256 constant PRECISION_FACTOR = 1e18;
  uint256 constant INITIAL_INTEREST_RATE = 5e10;

  event RebaseToken__InterestRateSet(uint256 interestRate);

  function setUp() public {
    owner = makeAddr("owner");
    minter = makeAddr("minter");
    user1 = makeAddr("user1");
    user2 = makeAddr("user2");

    vm.prank(owner);
    rebaseToken = new RebaseToken();
  }

  // ============= Constructor Tests =============
  function test_ConstructorSetsOwner() public {
    assertEq(rebaseToken.owner(), owner);
  }

  function test_ConstructorSetsTokenNameAndSymbol() public {
    assertEq(rebaseToken.name(), "RebaseToken");
    assertEq(rebaseToken.symbol(), "RBS");
  }

  function test_ConstructorSetsInitialInterestRate() public {
    assertEq(rebaseToken.getInterestRate(), INITIAL_INTEREST_RATE);
  }

  // ============= Mint Tests =============
  function test_MintRevertsWithoutMintBurnRole() public {
    vm.expectRevert();
    rebaseToken.mint(user1, 100e18);
  }

  function test_MintWorksWithMintBurnRole() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 100e18);
  }

  function test_MintSetsUserInterestRate() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(minter);
    rebaseToken.mint(user1, 50e18);

    // Interest rate should remain the same as the first mint
    assertEq(rebaseToken.principalBalanceOf(user1), 150e18);
  }

  function test_MintZeroAmount() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 0);

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
  }

  function test_MintMultipleTimes() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(minter);
    rebaseToken.mint(user1, 50e18);

    vm.prank(minter);
    rebaseToken.mint(user1, 25e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 175e18);
  }

  // ============= Burn Tests =============
  function test_BurnRevertsWithoutMintBurnRole() public {
    vm.expectRevert();
    rebaseToken.burn(user1, 100e18);
  }

  function test_BurnWorksWithMintBurnRole() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(minter);
    rebaseToken.burn(user1, 50e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 50e18);
  }

  function test_BurnMaxAmount() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(minter);
    rebaseToken.burn(user1, type(uint256).max);

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
  }

  function test_BurnZeroAmount() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(minter);
    rebaseToken.burn(user1, 0);

    assertEq(rebaseToken.principalBalanceOf(user1), 100e18);
  }

  function test_BurnMintAccruedInterest() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    // Simulate time passing
    vm.warp(block.timestamp + 365 days);

    uint256 principalBefore = rebaseToken.principalBalanceOf(user1);
    uint256 balanceBefore = rebaseToken.balanceOf(user1);

    vm.prank(minter);
    rebaseToken.burn(user1, 50e18);

    // Interest should have been minted before burning
    assert(balanceBefore > principalBefore);
  }

  // ============= Interest Rate Tests =============
  function test_SetInterestRateOnlyOwner() public {
    vm.expectRevert();
    vm.prank(user1);
    rebaseToken.setInterestRate(4e10);
  }

  function test_SetInterestRateCanOnlyDecrease() public {
    uint256 currentRate = rebaseToken.getInterestRate();

    vm.expectRevert(
      abi.encodeWithSelector(RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector, currentRate, 5e10)
    );
    vm.prank(owner);
    rebaseToken.setInterestRate(5e10);
  }

  function test_SetInterestRateHigherValueReverts() public {
    uint256 currentRate = rebaseToken.getInterestRate();

    vm.expectRevert();
    vm.prank(owner);
    rebaseToken.setInterestRate(currentRate + 1);
  }

  function test_SetInterestRateDecreases() public {
    vm.prank(owner);
    rebaseToken.setInterestRate(4e10);

    assertEq(rebaseToken.getInterestRate(), 4e10);
  }

  function test_SetInterestRateEmitsEvent() public {
    uint256 newRate = 4e10;

    vm.expectEmit(true, true, true, true);
    emit RebaseToken__InterestRateSet(newRate);

    vm.prank(owner);
    rebaseToken.setInterestRate(newRate);
  }

  function test_SetInterestRateToZero() public {
    vm.prank(owner);
    rebaseToken.setInterestRate(0);

    assertEq(rebaseToken.getInterestRate(), 0);
  }

  // ============= Balance Tests =============
  function test_BalanceOfReturnsZeroForNewAccount() public {
    assertEq(rebaseToken.balanceOf(user1), 0);
  }

  function test_PrincipalBalanceOf() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 100e18);
  }

  function test_BalanceOfIncreaseWithTime() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    uint256 balanceBefore = rebaseToken.balanceOf(user1);

    // Simulate time passing
    vm.warp(block.timestamp + 365 days);

    uint256 balanceAfter = rebaseToken.balanceOf(user1);

    assert(balanceAfter > balanceBefore);
  }

  function test_BalanceOfCalculationWithInterestRate() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    uint256 timePassed = 1 days;
    vm.warp(block.timestamp + timePassed);

    uint256 principal = rebaseToken.principalBalanceOf(user1);
    uint256 currentBalance = rebaseToken.balanceOf(user1);

    // Calculate expected balance with linear interest
    // balance = principal * (1 + rate * time)
    uint256 linearInterest = (INITIAL_INTEREST_RATE * timePassed) + PRECISION_FACTOR;
    uint256 expectedBalance = (principal * linearInterest) / PRECISION_FACTOR;

    assertEq(currentBalance, expectedBalance);
  }

  // ============= Transfer Tests =============
  function test_TransferBasic() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.transfer(user2, 50e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 50e18);
    assertEq(rebaseToken.principalBalanceOf(user2), 50e18);
  }

  function test_TransferMaxAmount() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.transfer(user2, type(uint256).max);

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
    assertEq(rebaseToken.principalBalanceOf(user2), 100e18);
  }

  function test_TransferSetsRecipientInterestRate() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    // Decrease global interest rate
    vm.prank(owner);
    rebaseToken.setInterestRate(3e10);

    // Transfer to user2 who has no balance
    vm.prank(user1);
    rebaseToken.transfer(user2, 50e18);

    // user2 should have the global interest rate at transfer time
  }

  function test_TransferToZeroBalanceRecipient() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.transfer(user2, 50e18);

    assertEq(rebaseToken.principalBalanceOf(user2), 50e18);
  }

  function test_TransferWithAccruedInterest() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.warp(block.timestamp + 365 days);

    vm.prank(user1);
    rebaseToken.transfer(user2, 50e18);

    // Interest should have been minted before transfer
  }

  function test_TransferZeroAmount() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.transfer(user2, 0);

    assertEq(rebaseToken.principalBalanceOf(user1), 100e18);
    assertEq(rebaseToken.principalBalanceOf(user2), 0);
  }

  // ============= TransferFrom Tests =============
  function test_TransferFromBasic() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.approve(minter, 50e18);

    vm.prank(minter);
    rebaseToken.transferFrom(user1, user2, 50e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 50e18);
    assertEq(rebaseToken.principalBalanceOf(user2), 50e18);
  }

  function test_TransferFromMaxAmount() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.approve(minter, type(uint256).max);

    vm.prank(minter);
    rebaseToken.transferFrom(user1, user2, type(uint256).max);

    assertEq(rebaseToken.principalBalanceOf(user1), 0);
    assertEq(rebaseToken.principalBalanceOf(user2), 100e18);
  }

  function test_TransferFromWithInsufficientApproval() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.approve(minter, 30e18);

    vm.expectRevert();
    vm.prank(minter);
    rebaseToken.transferFrom(user1, user2, 50e18);
  }

  function test_TransferFromToZeroBalanceRecipient() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.approve(minter, 50e18);

    vm.prank(minter);
    rebaseToken.transferFrom(user1, user2, 50e18);

    assertEq(rebaseToken.principalBalanceOf(user2), 50e18);
  }

  function test_TransferFromZeroAmount() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.approve(minter, 50e18);

    vm.prank(minter);
    rebaseToken.transferFrom(user1, user2, 0);

    assertEq(rebaseToken.principalBalanceOf(user1), 100e18);
    assertEq(rebaseToken.principalBalanceOf(user2), 0);
  }

  // ============= Access Control Tests =============
  function test_GrantMintBurnRoleOnlyOwner() public {
    vm.expectRevert();
    vm.prank(user1);
    rebaseToken.grantMintBurnRole(minter);
  }

  function test_GrantMintBurnRole() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    // This should not revert
    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);
  }

  function test_MultipleMintersAllowed() public {
    address minter2 = makeAddr("minter2");

    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter2);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(minter2);
    rebaseToken.mint(user2, 50e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 100e18);
    assertEq(rebaseToken.principalBalanceOf(user2), 50e18);
  }

  // ============= Edge Cases & Security Tests =============
  function test_MintMultipleToSameUser() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 50e18);

    vm.prank(minter);
    rebaseToken.mint(user1, 50e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 100e18);
  }

  function test_TransferToSelf() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.prank(user1);
    rebaseToken.transfer(user1, 50e18);

    assertEq(rebaseToken.principalBalanceOf(user1), 100e18);
  }

  function test_InterestCalculationAfterDecreaseRate() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.warp(block.timestamp + 1 days);

    uint256 balanceDay1 = rebaseToken.balanceOf(user1);

    // Decrease interest rate
    vm.prank(owner);
    rebaseToken.setInterestRate(2e10);

    vm.warp(block.timestamp + 1 days);

    uint256 balanceDay2 = rebaseToken.balanceOf(user1);

    // Balance should still increase, but at a slower rate
    assert(balanceDay2 > balanceDay1);
  }

  function test_TotalSupplyIncreaseAfterMint() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    uint256 supplyBefore = rebaseToken.totalSupply();

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    uint256 supplyAfter = rebaseToken.totalSupply();

    assertEq(supplyAfter - supplyBefore, 100e18);
  }

  function test_TotalSupplyDecreaseAfterBurn() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    uint256 supplyBefore = rebaseToken.totalSupply();

    vm.prank(minter);
    rebaseToken.burn(user1, 50e18);

    uint256 supplyAfter = rebaseToken.totalSupply();

    assertEq(supplyBefore - supplyAfter, 50e18);
  }

  function test_BalanceConsistencyAfterMultipleOperations() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    vm.warp(block.timestamp + 100);

    vm.prank(user1);
    rebaseToken.transfer(user2, 50e18);

    vm.warp(block.timestamp + 100);

    vm.prank(minter);
    rebaseToken.mint(user1, 50e18);

    vm.warp(block.timestamp + 100);

    uint256 principal1 = rebaseToken.principalBalanceOf(user1);
    uint256 principal2 = rebaseToken.principalBalanceOf(user2);

    assertGe(rebaseToken.balanceOf(user1), principal1);
    assertGe(rebaseToken.balanceOf(user2), principal2);
  }

  function test_InterestAccrualWithDecreasingRate() public {
    vm.prank(owner);
    rebaseToken.grantMintBurnRole(minter);

    vm.prank(minter);
    rebaseToken.mint(user1, 100e18);

    uint256 initialBalance = rebaseToken.balanceOf(user1);

    // Decrease interest rate
    vm.prank(owner);
    rebaseToken.setInterestRate(3e10);

    vm.warp(block.timestamp + 365 days);

    // Balance should still increase with decreased interest rate
    uint256 finalBalance = rebaseToken.balanceOf(user1);
    assertGt(finalBalance, initialBalance);
  }
}
