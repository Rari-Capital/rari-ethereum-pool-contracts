/**
 * @file
 * @author David Lucid <david@rari.capital>
 *
 * @section LICENSE
 *
 * All rights reserved to David Lucid of David Lucid LLC.
 * Any disclosure, reproduction, distribution or other use of this code by any individual or entity other than David Lucid of David Lucid LLC, unless given explicit permission by David Lucid of David Lucid LLC, is prohibited.
 *
 * @section DESCRIPTION
 *
 * This file includes the Ethereum contract code for CompoundPoolController, a library handling deposits to and withdrawals from dYdX liquidity pools.
 */

pragma solidity ^0.5.7;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../../external/compound/CEther.sol";

/**
 * @title CompoundPoolController
 * @dev This library handles deposits to and withdrawals from dYdX liquidity pools.
 */
library CompoundPoolController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address constant private cETH_CONTACT_ADDRESS = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; 
    CEther constant private _cETHContract = CEther(cETH_CONTACT_ADDRESS);

    /**
     * @dev Returns the fund's balance of the specified currency in the Compound pool.
     * We would simply be using balanceOfUnderlying, but exchangeRateCurrent is nonReentrant, which causes us issues.
     */
    function getBalance() internal returns (uint256) {
        // _cETHContract.accrueInterest(); // called when exchangeRateStored is called (see src)
        return _cETHContract.balanceOf(address(this)).mul(_cETHContract.exchangeRateCurrent()).div(1e18);
    }

    /**
     * @dev Approves tokens to Compound without spending gas on every deposit.
     * @param amount Amount of the specified token to approve to Compound.
     * @return Boolean indicating success.
     */
    function approve(uint256 amount) internal returns (bool) {
        IERC20 token = IERC20(cETH_CONTACT_ADDRESS);
        uint256 allowance = token.allowance(address(this), cETH_CONTACT_ADDRESS);
        if (allowance == amount) return true;
        if (amount > 0 && allowance > 0) token.safeApprove(cETH_CONTACT_ADDRESS, 0);
        token.safeApprove(cETH_CONTACT_ADDRESS, amount);
        return true;
    }

    /**
     * @dev Deposits funds to the Compound pool. Assumes that you have already approved >= the amount to Compound.
     * @param amount The amount of tokens to be deposited.
     * @return Boolean indicating success.
     */
    function deposit(uint256 amount) internal returns (bool) {
        require(amount > 0, "Amount must be greater than 0.");
        _cETHContract.mint.value(amount)();
        // require(mintResult == 0, "Error calling mint on Compound cToken: error code not equal to 0");
        return true;
    }

    /**
     * @dev Withdraws funds from the Compound pool.
     * @param amount The amount of tokens to be withdrawn.
     * @return Boolean indicating success.
     */
    function withdraw(uint256 amount) internal returns (bool) {
        require(amount > 0, "Amount must be greater than to 0.");
        uint256 redeemResult = _cETHContract.redeemUnderlying(amount);
        require(redeemResult == 0, "Error calling redeemUnderlying on Compound cToken: error code not equal to 0");
        return true;
    }

    /**
     * @dev Withdraws all funds from the Compound pool.
     * @return Boolean indicating success.
     */
    function withdrawAll() internal returns (bool) {
        uint256 balance = _cETHContract.balanceOf(address(this));
        if (balance <= 0) return false; // TODO: Or revert("No funds available to redeem from Compound cToken.")
        uint256 redeemResult = _cETHContract.redeem(balance);
        require(redeemResult == 0, "Error calling redeem on Compound cToken: error code not equal to 0");
        return true;
    }
}
