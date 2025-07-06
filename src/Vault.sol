// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interface/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseToken;

    // Errors
    error Vault__RedeemFailed();
    error Vault__DepositAmountShouldbeGreaterThanZero();
    error Vault__RedeemAmountShouldbeGreaterThanZero();

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    /**
     * @notice Fallback function to accept ETH rewards sent directly to the contract.
     * @dev This function allows the contract to receive ETH without any specific function call (call data).
     */
    receive() external payable {}

    /**
     * @notice Allows a user to deposit ETH and receive an equivalent amount of RebaseTokens.
     */
    function deposit() external payable {
        uint256 amountToMint = msg.value;
        if (amountToMint <= 0) {
            revert Vault__DepositAmountShouldbeGreaterThanZero();
        }

        // Mint RebaseToken to the user based on the amount of ETH deposited

        i_rebaseToken.mint(msg.sender, amountToMint);

        emit Deposit(msg.sender, amountToMint);
    }

    /**
     * @notice Allows a user to burn their RebaseTokens and receive a corresponding amount of ETH.
     * @param _amount The amount of RebaseTokens to redeem.
     * @dev Follows Checks-Effects-Interactions pattern. Uses low-level .call for ETH transfer.
     */
    function redeem(uint256 _amount) external {
        if (_amount <= 0) {
            revert Vault__DepositAmountShouldbeGreaterThanZero();
        }

        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }

        // 1. Effects (State changes occur first)
        // Burn the specified amount of tokens from the caller (msg.sender)
        // The RebaseToken's burn function should handle checks for sufficient balance.
        i_rebaseToken.burn(msg.sender, _amount);

        // 2. Interactions (External calls after state changes)
        // low level call to transfer ETH back to the user
        (bool success,) = payable(msg.sender).call{value: _amount}("");

        if (!success) {
            revert Vault__RedeemFailed();
        }

        emit Redeem(msg.sender, _amount);
    }
}
