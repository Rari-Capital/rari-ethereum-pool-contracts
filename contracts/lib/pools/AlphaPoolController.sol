// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "../../external/alpha/Bank.sol";

/**
 * @title AlphaPoolController
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @dev This library handles deposits to and withdrawals from Alpha Homora's ibETH pool.
 */
library AlphaPoolController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * @dev Alpha Homora ibETH token contract address.
     */
    address constant private IBETH_CONTRACT = 0x67B66C99D3Eb37Fa76Aa3Ed1ff33E8e39F0b9c7A;

    /**
     * @dev Alpha Homora ibETH token contract object.
     */
    Bank constant private _ibEth = Bank(IBETH_CONTRACT);

    /**
     * @dev Returns the fund's balance of the specified currency in the ibETH pool.
     */
    function getBalance() external view returns (uint256) {
        return _ibEth.balanceOf(address(this)).mul(_ibEth.totalETH()).div(_ibEth.totalSupply());
    }

    /**
     * @dev Deposits funds to the ibETH pool. Assumes that you have already approved >= the amount to the ibETH token contract.
     * @param amount The amount of ETH to be deposited.
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _ibEth.deposit.value(amount)();
    }

    /**
     * @dev Withdraws funds from the ibETH pool.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        uint256 totalEth = _ibEth.totalETH();
        uint256 totalSupply = _ibEth.totalSupply();
        uint256 credits = amount.mul(totalSupply).div(totalEth);
        if (credits.mul(totalEth).div(totalSupply) < amount) credits++; // Round up if necessary (i.e., if the division above left a remainder)
        _ibEth.withdraw(credits);
    }

    /**
     * @dev Withdraws all funds from the ibETH pool.
     * @return Boolean indicating success.
     */
    function withdrawAll() external returns (bool) {
        uint256 balance = _ibEth.balanceOf(address(this));
        if (balance <= 0) return false;
        _ibEth.withdraw(balance);
        return true;
    }
}