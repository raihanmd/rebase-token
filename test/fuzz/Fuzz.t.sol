// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {IRebaseToken} from "../../src/interface/IRebaseToken.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";

contract FuzzTest is Test {
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

  function addRewardToVault(uint256 amount) internal {
    (bool _success,) = payable(address(vault)).call{value: amount}("");
  }

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
    vm.deal(owner, 1000 ether);
    vm.deal(user1, 100 ether);
    vm.deal(user2, 100 ether);
    vm.deal(attacker, 100 ether);
  }

  function test_depositLinear(uint256 amount) public {
    amount = bound(amount, 1e5, type(uint96).max);

    vm.startPrank(user1);
    vm.deal(user1, amount);

    vault.deposit{value: amount}();

    uint256 initialBalance = rebaseToken.balanceOf(user1);
    console2.log("Start balance ", initialBalance);

    assertEq(initialBalance, amount);

    vm.warp(block.timestamp + 1 hours);

    uint256 secondCheckBalance = rebaseToken.balanceOf(user1);
    console2.log("Second check balance ", secondCheckBalance);

    assertGt(secondCheckBalance, initialBalance);

    vm.warp(block.timestamp + 1 hours);

    uint256 endCheckBalance = rebaseToken.balanceOf(user1);
    console2.log("End check balance ", endCheckBalance);

    assertGt(endCheckBalance, secondCheckBalance);

    assertApproxEqAbs(secondCheckBalance - initialBalance, endCheckBalance - secondCheckBalance, 1);

    vm.stopPrank();
  }

  function test_redeemStraightAway(uint256 amount) public {
    amount = bound(amount, 1e5, type(uint96).max);

    vm.startPrank(user1);
    vm.deal(user1, amount);

    vault.deposit{value: amount}();
    assertEq(rebaseToken.balanceOf(user1), amount);

    vault.redeem(type(uint256).max);
    assertEq(rebaseToken.balanceOf(user1), 0);
    assertEq(address(user1).balance, amount);

    vm.stopPrank();
  }

  function test_redeemAfterTimePassed(uint256 amount, uint256 time) public {
    time = bound(time, 1e8, type(uint96).max);
    amount = bound(amount, 1e5, type(uint96).max);

    vm.deal(user1, amount);
    vm.prank(user1);
    vault.deposit{value: amount}();
    assertEq(rebaseToken.balanceOf(user1), amount);

    vm.warp(block.timestamp + time);
    uint256 balanceAfterWarp = rebaseToken.balanceOf(user1);
    console2.log("Balance after warp ", balanceAfterWarp);

    vm.deal(owner, balanceAfterWarp - amount);

    vm.prank(owner);
    addRewardToVault(balanceAfterWarp - amount);

    vm.prank(user1);
    vault.redeem(type(uint256).max);
    assertEq(rebaseToken.balanceOf(user1), 0);

    uint256 ethBalance = address(user1).balance;

    assertEq(ethBalance, balanceAfterWarp);
    assertGt(ethBalance, amount);
  }
}

