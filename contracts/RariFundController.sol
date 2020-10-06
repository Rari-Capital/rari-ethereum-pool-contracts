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
 * This file includes the Ethereum contract code for RariFundController, our library handling deposits to and withdrawals from the liquidity pools that power RariFund as well as currency exchanges via 0x.
 */

pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/drafts/SignedSafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "@0x/contracts-exchange-libs/contracts/src/LibOrder.sol";

import "./lib/pools/DydxPoolController.sol";
import "./lib/pools/CompoundPoolController.sol";
import "./lib/pools/KeeperDaoPoolController.sol";
import "./lib/exchanges/ZeroExExchangeController.sol";

/**
 * @title RariFundController
 * @dev This contract handles deposits to and withdrawals from the liquidity pools that power RariFund as well as currency exchanges via 0x.
 */
contract RariFundController is Ownable {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeERC20 for IERC20;

    /**
     * @dev Boolean that, if true, disables the primary functionality of this RariFundController.
     */
    bool private _fundDisabled;

    /**
     * @dev Address of the RariFundManager.
     */
    address payable private _rariFundManagerContract;

    /**
     * @dev Address of the rebalancer.
     */
    address private _rariFundRebalancerAddress;

    /**
     * @dev Maps arrays of supported pools to currency codes.
     */
    uint8[] private _supportedPools;


    address constant private WETH_CONTRACT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev Caches the balances for each pool, with the sum cached at the end
     */
    uint256[] private _cachedBalances;

    /**
     * @dev Constructor that sets supported ERC20 token contract addresses and supported pools for each supported token.
     */
    constructor () public {
        // Add supported pools
        addPool(0); // dydx
        addPool(1); // compound
        addPool(2); // keeperdao
    }

    /**
     * @dev Initializes the balance cache, pushing a value for each pool and then the sum of them all.
     */
     /*
    function initBalanceCache() internal {
        for (uint8 i = 0; i < _supportedPools.length; i++) {
            _cachedBalances.push(0);
        }

        _cachedBalances.push(0); // Cached total balance;

        return true;
    }
    */

    /**
     * @dev Adds a supported pool for a token.
     * @param pool Pool ID to be supported.
     */
    function addPool(uint8 pool) internal {
        _supportedPools.push(pool);
    }

    /**
     * @dev Payable fallback function called by 0x exchange to refund unspent protocol fee.
     */
    function () external payable {
        // should deposit here
    }

    /**
     * @dev Emitted when the RariFundManager of the RariFundController is set.
     */
    event FundManagerSet(address newAddress);

    /**
     * @dev Sets or upgrades the RariFundManager of the RariFundController.
     * @param newContract The address of the new RariFundManager contract.
     */
    function setFundManager(address payable newContract) external onlyOwner {
        IERC20 weth = IERC20(WETH_CONTRACT);
        if (_rariFundManagerContract != address(0)) weth.safeApprove(_rariFundManagerContract, 0);
        if (newContract != address(0)) weth.safeApprove(newContract, uint256(-1));
        _rariFundManagerContract = newContract;
        emit FundManagerSet(newContract);
    }

    /**
     * @dev Throws if called by any account other than the RariFundManager.
     */
    modifier onlyManager() {
        require(_rariFundManagerContract == msg.sender, "Caller is not the fund manager.");
        _;
    }

    /**
     * @dev Emitted when the rebalancer of the RariFundController is set.
     */
    event FundRebalancerSet(address newAddress);

    /**
     * @dev Sets or upgrades the rebalancer of the RariFundController.
     * @param newAddress The Ethereum address of the new rebalancer server.
     */
    function setFundRebalancer(address newAddress) external onlyOwner {
        _rariFundRebalancerAddress = newAddress;
        emit FundRebalancerSet(newAddress);
    }

    /**
     * @dev Throws if called by any account other than the rebalancer.
     */
    modifier onlyRebalancer() {
        require(_rariFundRebalancerAddress == msg.sender, "Caller is not the rebalancer.");
        _;
    }

    /**
     * @dev Emitted when the primary functionality of this RariFundController contract has been disabled.
     */
    event FundDisabled();

    /**
     * @dev Emitted when the primary functionality of this RariFundController contract has been enabled.
     */
    event FundEnabled();

    /**
     * @dev Disables primary functionality of this RariFundController so contract(s) can be upgraded.
     */
    function disableFund() external onlyOwner {
        require(!_fundDisabled, "Fund already disabled.");
        _fundDisabled = true;
        emit FundDisabled();
    }

    /**
     * @dev Enables primary functionality of this RariFundController once contract(s) are upgraded.
     */
    function enableFund() external onlyOwner {
        require(_fundDisabled, "Fund already enabled.");
        _fundDisabled = false;
        emit FundEnabled();
    }

    /**
     * @dev Throws if fund is disabled.
     */
    modifier fundEnabled() {
        require(!_fundDisabled, "This fund controller contract is disabled. This may be due to an upgrade.");
        _;
    }

    /**
     * @dev Returns the balances of all currencies supported by dYdX.
     * @return An array of ERC20 token contract addresses and a corresponding array of balances.
     
    function getDydxBalances() external view returns (address[] memory, uint256[] memory) {
        return DydxPoolController.getBalances();
    }
    */

    /**
     * @dev Returns the fund controller's balance of the specified currency in the specified pool.
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `CompoundPoolController.getBalance`) potentially modifies the state.
     * @param pool The index of the pool.
     */
    function _getPoolBalance(uint8 pool) public returns (uint256) {
        if (pool == 0) return DydxPoolController.getBalance();
        else if (pool == 1) return CompoundPoolController.getBalance();
        else if (pool == 2) return KeeperDaoPoolController.getBalance();
        else revert("Invalid pool index.");
    }

    /**
     * @dev Returns the fund controller's balance of the specified currency in the specified pool.
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `CompoundPoolController.getBalance`) potentially modifies the state.
     * @param pool The index of the pool.
     */
    function getPoolBalance(uint8 pool) public returns (uint256) {
        if (!_poolsWithFunds[pool]) return 0;
        return _getPoolBalance(pool);
    }

    /**
     * @notice Returns the fund controller's balance of each pool of the specified currency.
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `getPoolBalance`) potentially modifies the state.
     * @return An array of pool indexes and an array of corresponding balances.
     */
    function getEntireBalance() public returns (uint256) {
        uint256 sum = address(this).balance; // start with immediate eth balance
        for (uint256 i = 0; i < _supportedPools.length; i++) {
            sum = getPoolBalance(_supportedPools[i]).add(sum);
        }
        // if (cache) cachedTotalBalance = sum;
        return sum;
    }


    /**
     * @dev Approves tokens to the specified pool without spending gas on every deposit.
     * @param amount The amount of tokens to be approved.
     * @return Boolean indicating success.
     */
    function approveWethToDydxPool(uint256 amount) external fundEnabled onlyRebalancer returns (bool) {
        require(DydxPoolController.approve(amount), "Approval of WETH to dYdX failed.");
        // We don't need approval from Compound if we're working with ETH
        // else if (pool == 1) require(CompoundPoolController.approve(erc20Contract, amount), "Approval of tokens to Compound failed.");
        // else revert("Invalid pool index.");
        return true;
    }

    /**
     * @dev Mapping of bools indicating the presence of funds to pools.
     */
    mapping(uint8 => bool) _poolsWithFunds;

    /**
     * @dev Return a boolean indicating if the fund controller has funds in `currencyCode` in `pool`.
     * @param pool The index of the pool to check.
     */
    function hasETHInPool(uint8 pool) external view returns (bool) {
        return _poolsWithFunds[pool];
    }

    /**
     * @dev Deposits funds to the specified pool.
     * @param pool The index of the pool.
     * @return Boolean indicating success.
     */
    function depositToPool(uint8 pool) payable external fundEnabled   returns (bool) {
        require(msg.value > 0, "Amount too small.");
        if (pool == 0) require(DydxPoolController.deposit(msg.value), "Deposit to dYdX failed.");
        else if (pool == 1) require(CompoundPoolController.deposit(msg.value), "Deposit to Compound failed.");
        else if (pool == 2) require(KeeperDaoPoolController.deposit(msg.value), "Deposit to KeeeperDao failed.");
        else revert("Invalid pool index.");
        _poolsWithFunds[pool] = true; 
        return true;
    }

    /**
     * @dev Internal function to withdraw funds from the specified pool.
     * @param pool The index of the pool.
     * @param amount The amount of tokens to be withdrawn.
     */
    function _withdrawFromPool(uint8 pool, uint256 amount) internal {
        if (pool == 0) require(DydxPoolController.withdraw(amount), "Withdrawal from dYdX failed.");
        else if (pool == 1) require(CompoundPoolController.withdraw(amount), "Withdrawal from Compound failed.");
        else if (pool == 2) require(KeeperDaoPoolController.withdraw(amount), "Withdrawal from KeeeperDao failed.");
        else revert("Invalid pool index.");
    }

    /**
     * @dev Withdraws funds from the specified pool.
     * @param pool The index of the pool.
     * @param amount The amount of tokens to be withdrawn.
     * @return Boolean indicating success.
     */
    function withdrawFromPool(uint8 pool, uint256 amount) external fundEnabled onlyRebalancer returns (bool) {
        _withdrawFromPool(pool, amount);
        _poolsWithFunds[pool] = _getPoolBalance(pool) > 0;
        return true;
    }

    /**
     * @dev Withdraws funds from the specified pool (caching the `initialBalance` parameter).
     * @param pool The index of the pool.
     * @param amount The amount of tokens to be withdrawn.
     * @param initialBalance The fund's balance of the specified currency in the specified pool before the withdrawal.
     * @return Boolean indicating success.
     */
    function withdrawFromPoolKnowingBalance(uint8 pool, uint256 amount, uint256 initialBalance) external fundEnabled onlyManager returns (bool) {
        _withdrawFromPool(pool, amount);
        if (amount == initialBalance) _poolsWithFunds[pool] = false;
        return true;
    }

    /**
     * @dev Withdraws funds from the specified pool and sends it to RariFundManager (caching the `initialBalance` parameter).
     * @param pool The index of the pool.
     * @param amount The amount of ETH to be withdrawn.
     * @param initialBalance The fund's balance of the specified currency in the specified pool before the withdrawal.
     * @return Boolean indicating success.
     */
    function withdrawFromPoolKnowingBalanceToManager(uint8 pool, uint256 amount, uint256 initialBalance) external fundEnabled onlyManager returns (bool) {
        _withdrawFromPool(pool, amount);
        if (amount == initialBalance) _poolsWithFunds[pool] = false;
        _rariFundManagerContract.transfer(amount); // Send funds to manager
        return true;
    }

    /**
     * @dev Withdraws all funds from the specified pool.
     * @param pool The index of the pool.
     * @return Boolean indicating success.
     */
    function withdrawAllFromPool(uint8 pool) external fundEnabled onlyRebalancer returns (bool) {
        if (pool == 0) require(DydxPoolController.withdrawAll(), "Withdrawal from dYdX failed.");
        else if (pool == 1) require(CompoundPoolController.withdrawAll(), "Withdrawal from Compound failed.");
        else if (pool == 2) require(KeeperDaoPoolController.withdrawAll(), "Withdrawal from KeeperDao failed.");
        else revert("Invalid pool index.");
        _poolsWithFunds[pool] = false;
        return true;
    }

    /**
     * @dev Withdraws all funds from the specified pool (without requiring the fund to be enabled).
     * @param pool The index of the pool.
     * @return Boolean indicating success.
     */
    function withdrawAllFromPoolOnUpgrade(uint8 pool) external onlyManager returns (bool) {
        if (pool == 0) require(DydxPoolController.withdrawAll(), "Withdrawal from dYdX failed.");
        else if (pool == 1) require(CompoundPoolController.withdrawAll(), "Withdrawal from Compound failed.");
        else if (pool == 2) require(KeeperDaoPoolController.withdrawAll(), "Withdrawal from KeeperDao failed.");
        else revert("Invalid pool index.");
        _rariFundManagerContract.transfer(address(this).balance); // Transfer all ETH to RariFundManager for further processing
        _poolsWithFunds[pool] = false;
        return true;
    }


    /**
     * @dev Withdraws ETH and sends amount to the manager.
     * @param amount Amount of ETH to withdraw.
     * @return Boolean indicating success.
     */
    function withdrawToManager(uint256 amount) external onlyManager returns (bool) {
        require(amount < getEntireBalance(), "Withdrawal is too large.");
        uint256 immediateBalance = address(this).balance;

        if (immediateBalance >= amount) {
            _rariFundManagerContract.transfer(amount);
            return true;
        }

        for (uint256 i = 0; i < _supportedPools.length; i++) {
            if (immediateBalance >= amount) break;

            uint256 poolBalance = _getPoolBalance(_supportedPools[i]);
            if (poolBalance <= 0) continue;
            uint256 amountLeft = amount.sub(immediateBalance);
            uint256 poolAmount = amountLeft < poolBalance ? amountLeft : poolBalance;
            _withdrawFromPool(_supportedPools[i], poolAmount);
            immediateBalance = immediateBalance.add(poolAmount);
        }

        _rariFundManagerContract.transfer(amount);

        return true;
    }

    /**
     * @dev Approves tokens to 0x without spending gas on every deposit.
     * @param erc20Contract The ERC20 contract address of the token to be approved.
     * @param amount The amount of tokens to be approved.
     * @return Boolean indicating success.
     */
    function approveTo0x(address erc20Contract, uint256 amount) external fundEnabled onlyRebalancer returns (bool) {
        // COMP only
        // require(erc20Contract == )
        require(ZeroExExchangeController.approve(erc20Contract, amount), "Approval of tokens to 0x failed.");
        return true;
    }

    /**
     * @dev Market sell to 0x exchange orders (reverting if `takerAssetFillAmount` is not filled).
     * We should be able to make this function external and use calldata for all parameters, but Solidity does not support calldata structs (https://github.com/ethereum/solidity/issues/5479).
     * @param orders The limit orders to be filled in ascending order of price.
     * @param signatures The signatures for the orders.
     * @param takerAssetFillAmount The amount of the taker asset to sell (excluding taker fees).
     * @return Boolean indicating success.
     */
    function marketSell0xOrdersFillOrKill(LibOrder.Order[] memory orders, bytes[] memory signatures, uint256 takerAssetFillAmount) public payable fundEnabled onlyRebalancer returns (bool) {
        ZeroExExchangeController.marketSellOrdersFillOrKill(orders, signatures, takerAssetFillAmount, msg.value);
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) msg.sender.transfer(ethBalance);
        return true;
    }
}
