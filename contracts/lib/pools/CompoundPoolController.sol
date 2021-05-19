// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../../external/compound/CEther.sol";

/**
 * @title CompoundPoolController
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @author Richter Brzeski <richter@rari.capital> (https://github.com/richtermb)
 * @dev This library handles deposits to and withdrawals from Compound liquidity pools.
 */
library CompoundPoolController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address constant private cETH_CONTACT_ADDRESS = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; 
    CEther constant private _cETHContract = CEther(cETH_CONTACT_ADDRESS);

    /**
     * @dev Returns the fund's balance of the specified currency in the Compound pool.
     */
    function getBalance() external returns (uint256) {
        return _cETHContract.balanceOfUnderlying(address(this));
    }

    /**
     * @dev Deposits funds to the Compound pool. Assumes that you have already approved >= the amount to Compound.
     * @param amount The amount of tokens to be deposited.
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _cETHContract.mint.value(amount)();
    }

    /**
     * @dev Withdraws funds from the Compound pool.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than to 0.");
        uint256 redeemResult = _cETHContract.redeemUnderlying(amount);
        require(redeemResult == 0, "Error calling redeemUnderlying on Compound cToken: error code not equal to 0");
    }

    /**
     * @dev Withdraws all funds from the Compound pool.
     * @return Boolean indicating success.
     */
    function withdrawAll() external returns (bool) {
        uint256 balance = _cETHContract.balanceOf(address(this));
        if (balance <= 0) return false;
        uint256 redeemResult = _cETHContract.redeem(balance);
        require(redeemResult == 0, "Error calling redeem on Compound cToken: error code not equal to 0");
        return true;
    }
}
