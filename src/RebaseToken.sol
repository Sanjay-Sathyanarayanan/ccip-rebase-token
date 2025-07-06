// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Your Sanjay Sathyanarayanan
 * @notice This is a cross-chain rebase token that incentivises users to deposit into a vault and gain interest in rewards.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    // Errors
    error RebaseToken__InterestRateCanOnlyBeDecreased(uint256 newInterestRate, uint256 currentInterestRate);

    // State Variables
    uint256 private constant PRECISION_FACTOR = 1e18; // Used for scaling interest rates and calculations
    bytes32 private constant MINT_BURN_ROLE = keccak256("MINT_BURN_ROLE"); // Role for minting and burning tokens
    uint256 private s_interestRate = 5e10; // the interest rate in seconds, e.g., 5e10 means 5% interest 0.00000005

    mapping(address => uint256) private s_userInterestRate; // Maps user address to their interest rate
    mapping(address => uint256) private s_userLastUpdatedTimeStamp; // Maps user address to their last rebase timestamp

    // Events

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    /**
     * @notice Grants the MINT_BURN_ROLE to an account.
     * @dev This allows the account to mint and burn tokens.
     * @param _account The address to grant the MINT_BURN_ROLE to.
     */
    function grantMintBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_BURN_ROLE, _account);
    }

    /**
     * @dev Sets a new interest rate for the token.
     * @param _newInterestRate The new interest rate to be set.
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if (_newInterestRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyBeDecreased(_newInterestRate, s_interestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Returns the priciple balance of a user, which is minited tokens when they last interacted with the contract.
     * @dev This is the actual amount of tokens minted to the user, not including accrued
     * @param _user The address of the user to check the principle balance for.
     */
    function principleBalanceOf(address _user) external view returns (uint256) {
        // Returns the principal balance of the user, which is the actual amount of tokens minted to them.
        return super.balanceOf(_user);
    }

    /**
     * @notice Mints tokens to a user, typically upon deposit.
     * @dev Also mints accrued interest and locks in the current global rate for the user.
     * @param _to The address to mint tokens to.
     * @param _amount The principal amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_BURN_ROLE) {
        _mintAccruedInterest(_to); // Mint accrued interest before minting new tokens
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Returns the current balance of an account, including accrued interest.
     * @param _user The address of the account.
     * @return The total balance including interest.
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // Get the user's stored principal balance (tokens actually minted to them).
        uint256 principalBalance = super.balanceOf(_user);

        // Calculate the growth factor based on accrued interest.
        uint256 growthFactor = _calculateUserAccumulatedInterestSinceLastUpdate(_user);

        //PRECISION_FACTOR is used for scaling, so we divide by it here.
        return principalBalance * growthFactor / PRECISION_FACTOR;
    }

    /**
     * @notice Burn the user tokens, e.g., when they withdraw from a vault or for cross-chain transfers.
     * Handles burning the entire balance if _amount is type(uint256).max.
     * @param _from The user address from which to burn tokens.
     * @param _amount The amount of tokens to burn. Use type(uint256).max to burn all tokens.
     */
    function burn(address _from, uint256 _amount) external onlyRole(MINT_BURN_ROLE) {
        _mintAccruedInterest(_from); // Mint any accrued interest first

        _burn(_from, _amount);
    }
    /**
     * @notice Transfers tokens from the sender to a recipient, minting accrued interest for both parties.
     * @dev If _amount is type(uint256).max, transfers the entire balance of the sender.
     * @param _recipient The address to transfer tokens to.
     * @param _amount The amount of tokens to transfer. Use type(uint256).max to transfer all tokens.
     * @return True if the transfer was successful.
     */

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender); // If max, transfer all balance
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recipient, _amount);
    }

    /**
     * @notice Transfers tokens from one address to another, minting accrued interest for both parties.
     * @dev If _amount is type(uint256).max, transfers the entire balance of the sender.
     * @param _from The address to transfer tokens from.
     * @param _to The address to transfer tokens to.
     * @param _amount The amount of tokens to transfer. Use type(uint256).max to transfer all tokens.
     * @return True if the transfer was successful.
     */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);

        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from); // If max, transfer all balance
        }

        if (balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[_from];
        }

        return super.transferFrom(_from, _to, _amount);
    }

    /**
     * @dev Calculates the growth factor due to accumulated interest since the user's last update.
     * @param _user The address of the user.
     * @return linearInterestFactor The growth factor, scaled by PRECISION_FACTOR. (e.g., 1.05x growth is 1.05 * 1e18).
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user)
        internal
        view
        returns (uint256 linearInterestFactor)
    {
        // 1. Calculate the time elapsed since the user's balance was last effectively updated.
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];

        // If no time has passed, or if the user has no locked rate (e.g., never interacted),
        // the growth factor is simply 1 (scaled by PRECISION_FACTOR).
        if (timeElapsed == 0 || s_userInterestRate[_user] == 0) {
            return PRECISION_FACTOR;
        }

        // 2. Calculate the total fractional interest accrued: UserInterestRate * TimeElapsed.
        // s_userInterestRate[_user] is the rate per second.
        // This product is already scaled appropriately if s_userInterestRate is stored scaled.
        uint256 fractionalInterest = s_userInterestRate[_user] * timeElapsed;

        // 3. The growth factor is (1 + fractional_interest_part).
        // Since '1' is represented as PRECISION_FACTOR, and fractionalInterest is already scaled, we add them.
        linearInterestFactor = PRECISION_FACTOR + fractionalInterest;
        return linearInterestFactor;
    }

    function _mintAccruedInterest(address _to) internal {
        // (1) find the current balance of the rebase token that have been minted to the user
        uint256 previousPrincipleBalance = super.balanceOf(_to);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_to);
        // calculate the number of tokens that need to be minted to the user (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;

        s_userLastUpdatedTimeStamp[_to] = block.timestamp;

        // Mint the accrued interest (Interaction)
        if (balanceIncrease > 0) {
            // Optimization: only mint if there's interest
            _mint(_to, balanceIncrease);
        }
    }

    // getter functions

    /**
     * @notice Gets the locked-in interest rate for a specific user.
     * @param _user The address of the user.
     * @return The user's specific interest rate.
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
        return s_userInterestRate[_user];
    }

    /**
     * @notice Gets the current global interest rate.
     * @dev This is the interest rate that will be applied to new deposits.
     * @return The current interest rate.
     */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }
}
