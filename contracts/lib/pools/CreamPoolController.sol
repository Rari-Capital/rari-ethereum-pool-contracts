/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../../external/compound/CEther.sol";

/**
 * @title CreamPoolController
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @dev This library handles deposits to and withdrawals from Cream Finance liquidity pools.
 */
library CreamPoolController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @dev Cream Ether cToken (crETH) contract address.
     */
    address constant private CRETH_CONTACT_ADDRESS = 0xD06527D5e56A3495252A528C4987003b712860eE;

    /**
     * @dev Cream Ether cToken (crETH) contract object.
     */
    CEther constant private _crEthContract = CEther(CRETH_CONTACT_ADDRESS);

    /**
     * @dev Returns the fund's balance of the specified currency in the Cream pool.
     */
    function getBalance() external returns (uint256) {
        return _crEthContract.balanceOfUnderlying(address(this));
    }

    /**
     * @dev Deposits funds to the Cream pool. Assumes that you have already approved >= the amount to Cream.
     * @param amount The amount of tokens to be deposited.
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _crEthContract.mint.value(amount)();
    }

    /**
     * @dev Withdraws funds from the Cream pool.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than to 0.");
        uint256 redeemResult = _crEthContract.redeemUnderlying(amount);
        require(redeemResult == 0, "Error calling redeemUnderlying on Cream cToken: error code not equal to 0");
    }

    /**
     * @dev Withdraws all funds from the Cream pool.
     * @return Boolean indicating success.
     */
    function withdrawAll() external returns (bool) {
        uint256 balance = _crEthContract.balanceOf(address(this));
        if (balance <= 0) return false;
        uint256 redeemResult = _crEthContract.redeem(balance);
        require(redeemResult == 0, "Error calling redeem on Cream cToken: error code not equal to 0");
        return true;
    }
}
