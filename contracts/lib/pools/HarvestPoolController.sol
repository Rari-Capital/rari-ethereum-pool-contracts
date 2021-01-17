/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public APIs (described in `API.md` of the `rari-contracts` package) of the official smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license) benefitting Rari Capital, Inc.
 * Only those with explicit permission from a co-founder of Rari Capital (Jai Bhavnani, Jack Lipstone, or David Lucid) are permitted to study, review, or analyze any part of the source code contained in the `rari-contracts` package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in the `rari-contracts` package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "@0x/contracts-erc20/contracts/src/interfaces/IEtherToken.sol";

import "../../external/harvest/IVault.sol";

/**
 * @title HarvestPoolController
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @dev This library handles deposits to and withdrawals from Harvest Finance vaults.
 */
library HarvestPoolController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IVault;

    /**
     * @dev The Harvest WETH vault contract address.
     */
    address constant private WETH_VAULT_CONTRACT = 0xFE09e53A81Fe2808bc493ea64319109B5bAa573e;

    /**
     * @dev The Harvest WETH vault contract object.
     */
    IVault constant private _wethVault = IVault(WETH_VAULT_CONTRACT);

    /**
     * @dev The WETH contract address.
     */
    address constant private WETH_CONTRACT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev The WETH contract object.
     */
    IEtherToken constant private _weth = IEtherToken(WETH_CONTRACT);

    /**
     * @dev Returns the fund's balance of the specified currency in the Harvest vault.
     */
    function getBalance() external view returns (uint256) {
        return _wethVault.balanceOf(address(this)).mul(_wethVault.getPricePerFullShare()).div(1e18);
    }

    /**
     * @dev Approves WETH to the Harvest vault without spending gas on every deposit.
     * @param amount Amount of the specified token to approve.
     */
    function approve(uint256 amount) external {
        IERC20 token = IERC20(WETH_CONTRACT);
        uint256 allowance = token.allowance(address(this), WETH_VAULT_CONTRACT);
        if (allowance == amount) return;
        if (amount > 0 && allowance > 0) token.safeApprove(WETH_VAULT_CONTRACT, 0);
        token.safeApprove(WETH_VAULT_CONTRACT, amount);
    }

    /**
     * @dev Deposits ETH to the Harvest WETH vault. Assumes that you have already approved >= the amount of WETH to the vault.
     * @param amount The amount of ETH to be deposited.
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _weth.deposit.value(amount)();
        _wethVault.deposit(amount);
    }

    /**
     * @dev Withdraws ETH from the Harvest WETH vault.
     * @param amount The amount of ETH to be withdrawn.
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        uint256 pricePerFullShare = _wethVault.getPricePerFullShare();
        uint256 shares = amount.mul(1e18).div(pricePerFullShare);
        if (shares.mul(pricePerFullShare).div(1e18) < amount) shares++; // Round up if necessary (i.e., if the division above left a remainder)
        _wethVault.withdraw(shares);
        _weth.withdraw(_weth.balanceOf(address(this)));
    }

    /**
     * @dev Withdraws all ETH from the Harvest WETH vault.
     * @return Boolean indicating if any funds were withdrawn.
     */
    function withdrawAll() external returns (bool) {
        uint256 balance = _wethVault.balanceOf(address(this));
        if (balance <= 0) return false;
        _wethVault.withdraw(balance);
        _weth.withdraw(_weth.balanceOf(address(this)));
        return true;
    }

    /**
     * @dev Transfers all funds in the Harvest vault to another address.
     * @param to The recipient of the funds.
     * @return Boolean indicating if any funds were transferred.
     */
    function transferAll(address to) external returns (bool) {
        uint256 balance = _wethVault.balanceOf(address(this));
        if (balance <= 0) return false;
        _wethVault.safeTransfer(to, balance);
        return true;
    }
}
