// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IRebaseToken} from "./interface/IRebaseToken.sol";

/**
 *  @title Vault for the rebase token
 * @author raihanmd
 * @notice This contract do as the vault of the rebase token
 */
contract Vault {
  error Vault__TransferFailed(address to, uint256 amount);

  event Deposited(address indexed user, uint256 amount);
  event Redeemed(address indexed user, uint256 amount);

  IRebaseToken private immutable i_rebaseToken;

  constructor(IRebaseToken _address) {
    i_rebaseToken = _address;
  }

  /**
   * @notice Allows user to deposit their eth
   */
  function deposit() external payable {
    i_rebaseToken.mint(msg.sender, msg.value);
    emit Deposited(msg.sender, msg.value);
  }

  /**
   * @notice Allows user to redeem their eth
   * @param _amount the amount rebase token to be redeem
   */
  function redeem(uint256 _amount) external {
    if (_amount == type(uint256).max) {
      _amount = i_rebaseToken.balanceOf(msg.sender);
    }

    assert(_amount <= i_rebaseToken.balanceOf(msg.sender));

    i_rebaseToken.burn(msg.sender, _amount);

    (bool success,) = payable(msg.sender).call{value: _amount}("");

    if (!success) {
      revert Vault__TransferFailed(msg.sender, _amount);
    }

    emit Redeemed(msg.sender, _amount);
  }

  function getRebaseToken() external view returns (address) {
    return address(i_rebaseToken);
  }

  receive() external payable {}
}
