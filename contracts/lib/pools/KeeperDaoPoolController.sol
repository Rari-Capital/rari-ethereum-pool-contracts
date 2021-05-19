// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "@0x/contracts-erc20/contracts/src/interfaces/IEtherToken.sol";

import "../../external/keeperdao/ILiquidityPool.sol";
import "../../external/keeperdao/IKToken.sol";

/**
 * @title KeeperDaoPoolController
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @author Richter Brzeski <richter@rari.capital> (https://github.com/richtermb)
 * @dev This library handles deposits to and withdrawals from KeeperDAO liquidity pools.
 */
library KeeperDaoPoolController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address payable constant private KEEPERDAO_CONTRACT = 0x35fFd6E268610E764fF6944d07760D0EFe5E40E5;
    ILiquidityPool constant private _liquidityPool = ILiquidityPool(KEEPERDAO_CONTRACT);

    // KeeperDAO's representation of ETH
    address constant private ETHEREUM_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    /**
     * @dev Returns the fund's balance in the KeeperDAO pool.
     */
    function getBalance() external view returns (uint256) {
        return _liquidityPool.underlyingBalance(ETHEREUM_ADDRESS, address(this));
    }

    /**
     * @dev Approves kEther to KeeperDAO to burn without spending gas on every deposit.
     * @param amount Amount of kEther to approve to KeeperDAO.
     */
    function approve(uint256 amount) external {
        IKToken kEther = _liquidityPool.kToken(ETHEREUM_ADDRESS);
        uint256 allowance = kEther.allowance(address(this), KEEPERDAO_CONTRACT);
        if (allowance == amount) return;
        if (amount > 0 && allowance > 0) kEther.approve(KEEPERDAO_CONTRACT, 0);
        kEther.approve(KEEPERDAO_CONTRACT, amount);
    }

    /**
     * @dev Deposits funds to the KeeperDAO pool..
     * @param amount The amount of ETH to be deposited.
     */
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _liquidityPool.deposit.value(amount)(ETHEREUM_ADDRESS, amount);
    }

    /**
     * @dev Withdraws funds from the KeeperDAO pool.
     * @param amount The amount of ETH to be withdrawn.
     */
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0.");
        _liquidityPool.withdraw(address(uint160(address(this))), 
                                _liquidityPool.kToken(ETHEREUM_ADDRESS), 
                                calculatekEtherWithdrawAmount(amount));
    }

    /**
     * @dev Withdraws all funds from the KeeperDAO pool.
     * @return Boolean indicating success.
     */
    function withdrawAll() external returns (bool) {
        IKToken kEther = _liquidityPool.kToken(ETHEREUM_ADDRESS);
        uint256 balance = kEther.balanceOf(address(this));
        if (balance <= 0) return false;
        _liquidityPool.withdraw(address(uint160(address(this))), kEther, balance);
        return true;
    }

    /**
     * @dev Calculates an amount of kEther to withdraw equivalent to amount parameter in ETH.
     * @return amount to withdraw in kEther.
     */
    function calculatekEtherWithdrawAmount(uint256 amount) internal view returns (uint256) {
        IKToken kEther = _liquidityPool.kToken(ETHEREUM_ADDRESS);
        uint256 totalSupply = kEther.totalSupply();
        uint256 borrowableBalance = _liquidityPool.borrowableBalance(ETHEREUM_ADDRESS);
        uint256 kEtherAmount = amount.mul(totalSupply).div(borrowableBalance); 
        if (kEtherAmount.mul(borrowableBalance).div(totalSupply) < amount) kEtherAmount++;
        return kEtherAmount;
    }
}
