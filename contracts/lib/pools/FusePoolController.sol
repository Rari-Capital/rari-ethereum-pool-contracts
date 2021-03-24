/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.5.17;

import "../../external/compound/CEther.sol";

/**
 * @title FusePoolController
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @author Richter Brzeski <richter@rari.capital> (https://github.com/richtermb)
 * @dev This library handles deposits to and withdrawals from Fuse liquidity pools.
 */
library FusePoolController {
    /**
     * @dev Returns the fund's balance of the specified currency in the Fuse pool.
     * @param cEtherContract The cEther contract to interact with.
     */
    function getBalance(address cEtherContract) external returns (uint256) {
        return CEther(cEtherContract).balanceOfUnderlying(address(this));
    }

    /**
     * @dev Deposits funds to the Fuse pool. Assumes that you have already approved >= the amount to Fuse.0
     * @param cEtherContract The cEther contract to interact with.
     * @param amount The amount of tokens to be deposited.
     */
    function deposit(address cEtherContract, uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        CEther(cEtherContract).mint.value(amount)();
    }

    /**
     * @dev Withdraws funds from the Fuse pool.
     * @param cEtherContract The cEther contract to interact with.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(address cEtherContract, uint256 amount) external {
        require(amount > 0, "Amount must be greater than to 0.");
        uint256 redeemResult = CEther(cEtherContract).redeemUnderlying(amount);
        require(redeemResult == 0, "Error calling redeemUnderlying on Fuse cToken: error code not equal to 0.");
    }

    /**
     * @dev Withdraws all funds from the Fuse pool.
     * @param cEtherContract The cEther contract to interact with.
     * @return Boolean indicating success.
     */
    function withdrawAll(address cEtherContract) external returns (bool) {
        CEther cEther = CEther(cEtherContract);
        uint256 balance = cEther.balanceOf(address(this));
        if (balance <= 0) return false;
        uint256 redeemResult = cEther.redeem(balance);
        require(redeemResult == 0, "Error calling redeem on Fuse cToken: error code not equal to 0.");
        return true;
    }

    /**
     * @dev Transfers all funds from the Fuse pool.
     * @param cEtherContract The cEther contract to interact with.
     * @return Boolean indicating success.
     */
    function transferAll(address cEtherContract, address newContract) external returns (bool) {
        CEther cEther = CEther(cEtherContract);
        uint256 balance = cEther.balanceOf(address(this));
        if (balance <= 0) return false;
        require(cEther.transfer(newContract, balance), "Error calling transfer on Fuse cToken.");
        return true;
    }
}
