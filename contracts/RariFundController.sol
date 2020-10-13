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

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/drafts/SignedSafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "@0x/contracts-exchange-libs/contracts/src/LibOrder.sol";

import "./lib/pools/DydxPoolController.sol";
import "./lib/pools/CompoundPoolController.sol";
import "./lib/pools/KeeperDaoPoolController.sol";
import "./lib/pools/AavePoolController.sol";
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
     * @dev Boolean to be checked on `upgradeFundController`.
     */
    bool public constant IS_RARI_FUND_CONTROLLER = true;

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

    /**
     * @dev WETH contract address.
     */
    address constant private WETH_CONTRACT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev COMP token address.
     */
    address constant private COMP_TOKEN = 0xc00e94Cb662C3520282E6f5717214004A7f26888;


    /**
     * @dev Caches the balances for each pool, with the sum cached at the end
     */
    uint256[] private _cachedBalances;

    /**
     * @dev Constructor that sets supported ERC20 token contract addresses and supported pools for each supported token.
     */
    constructor () public {
        Ownable.initialize(msg.sender);
        // Add supported pools
        addPool(0); // dydx
        addPool(1); // compound
        addPool(2); // keeperdao
        addPool(3); // aave
    }


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
    function () external payable { }

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
     * @dev Sets or upgrades RariFundController by forwarding immediate balance of ETH from the old to the new.
     * @param newContract The address of the new RariFundController contract.
     */
    function _upgradeFundController(address payable newContract) external onlyOwner {
        require(RariFundController(newContract).IS_RARI_FUND_CONTROLLER(), "New contract does not have IS_RARI_FUND_CONTROLLER set to true.");
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = newContract.call.value(balance)("");
            require(success, "Failed to transfer ETH.");
        }
    }


    /**
     * @dev Sets or upgrades RariFundController by withdrawing all ETH from all pools and forwarding them from the old to the new.
     * @param newContract The address of the new RariFundController contract.
     */
    function upgradeFundController(address payable newContract) external onlyOwner {
        require(RariFundController(newContract).IS_RARI_FUND_CONTROLLER(), "New contract does not have IS_RARI_FUND_CONTROLLER set to true.");

        for (uint256 i = 0; i < _supportedPools.length; i++)
            if (hasETHInPool(_supportedPools[i]))
                _withdrawAllFromPool(_supportedPools[i]);

        uint256 balance = address(this).balance;

        if (balance > 0) {
            (bool success, ) = newContract.call.value(balance)("");
            require(success, "Failed to transfer ETH.");
        }
    }


    /**
     * @dev Returns the fund controller's balance of the specified currency in the specified pool.
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `CompoundPoolController.getBalance`) potentially modifies the state.
     * @param pool The index of the pool.
     */
    function _getPoolBalance(uint8 pool) public returns (uint256) {
        if (pool == 0) return DydxPoolController.getBalance();
        else if (pool == 1) return CompoundPoolController.getBalance();
        else if (pool == 2) return KeeperDaoPoolController.getBalance();
        else if (pool == 3) return AavePoolController.getBalance();
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
        return sum;
    }


    /**
     * @dev Approves WETH to dYdX pool without spending gas on every deposit.
     * @param amount The amount of WETH to be approved.
     * @return Boolean indicating success.
     */
    function approveWethToDydxPool(uint256 amount) external fundEnabled onlyRebalancer returns (bool) {
        require(DydxPoolController.approve(amount), "Approval of WETH to dYdX failed.");
        return true;
    }

    /**
     * @dev Approves kEther to the specified pool without spending gas on every deposit.
     * @param amount The amount of tokens to be approved.
     * @return Boolean indicating success.
     */
    function approvekEtherToKeeperDaoPool(uint256 amount) external fundEnabled onlyRebalancer returns (bool) {
        require(KeeperDaoPoolController.approve(amount), "Approval of kEther to KeeperDao failed.");
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
    function hasETHInPool(uint8 pool) public view returns (bool) {
        return _poolsWithFunds[pool];
    }

    /**
     * @dev Referral code for Aave deposits.
     */
    uint16 _aaveReferralCode;

    /**
     * @dev Sets the referral code for Aave deposits.
     * @param referralCode The referral code.
     */
    function setAaveReferralCode(uint16 referralCode) external onlyOwner {
        _aaveReferralCode = referralCode;
    }

    /**
     * @dev Deposits funds to the specified pool.
     * @param pool The index of the pool.
     * @return Boolean indicating success.
     */
    function depositToPool(uint8 pool, uint256 amount) external fundEnabled onlyRebalancer  returns (bool) {
        require(amount > 0, "Amount too small.");
        if (pool == 0) require(DydxPoolController.deposit(amount), "Deposit to dYdX failed.");
        else if (pool == 1) require(CompoundPoolController.deposit(amount), "Deposit to Compound failed.");
        else if (pool == 2) require(KeeperDaoPoolController.deposit(amount), "Deposit to KeeeperDao failed.");
        else if (pool == 3) AavePoolController.deposit(amount, _aaveReferralCode);
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
        else if (pool == 3) AavePoolController.withdraw(amount);
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
    function withdrawFromPoolKnowingBalance(uint8 pool, uint256 amount, uint256 initialBalance) public fundEnabled onlyManager returns (bool) {
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
        (bool success, ) = _rariFundManagerContract.call.value(amount)(""); // Send funds to manager
        require(success, "Failed to transfer ETH.");
        return true;
    }

    /**
     * @dev Internal function that withdraws all funds from the specified pool.
     * @param pool The index of the pool.
     * @return Boolean indicating success.
     */
    function _withdrawAllFromPool(uint8 pool) internal returns (bool) {
        if (pool == 0) require(DydxPoolController.withdrawAll(), "Withdrawal from dYdX failed.");
        else if (pool == 1) require(CompoundPoolController.withdrawAll(), "Withdrawal from Compound failed.");
        else if (pool == 2) require(KeeperDaoPoolController.withdrawAll(), "Withdrawal from KeeperDao failed.");
        else if (pool == 3) require(AavePoolController.withdrawAll(), "Withdrawal from Aave failed.");
        else revert("Invalid pool index.");
        _poolsWithFunds[pool] = false;
        return true;
    }


    /**
     * @dev Withdraws all funds from the specified pool.
     * @param pool The index of the pool.
     * @return Boolean indicating success.
     */
    function withdrawAllFromPool(uint8 pool) external fundEnabled onlyRebalancer returns (bool) {
        return _withdrawAllFromPool(pool);
    }

    /**
     * @dev Withdraws all funds from the specified pool (without requiring the fund to be enabled).
     * @param pool The index of the pool.
     * @return Boolean indicating success.
     */
    function withdrawAllFromPoolOnUpgrade(uint8 pool) external onlyOwner returns (bool) {
        return _withdrawAllFromPool(pool);
    }


    /**
     * @dev Withdraws ETH and sends amount to the manager.
     * @param amount Amount of ETH to withdraw.
     * @return Boolean indicating success.
     */
    function withdrawToManager(uint256 amount) external onlyManager returns (bool) {
        // Input validation
        require(amount > 0, "Withdrawal amount must be greater than 0.");

        // Check contract balance and withdraw from pools if necessary
        uint256 contractBalance = address(this).balance; // get ETH balance

        for (uint256 i = 0; i < _supportedPools.length; i++) {
            if (contractBalance >= amount) break;
            uint8 pool = _supportedPools[i];
            uint256 poolBalance = getPoolBalance(pool);
            if (poolBalance <= 0) continue;
            uint256 amountLeft = amount.sub(contractBalance);
            uint256 poolAmount = amountLeft < poolBalance ? amountLeft : poolBalance;
            require(withdrawFromPoolKnowingBalance(pool, poolAmount, poolBalance), "Pool withdrawal failed.");
            contractBalance = contractBalance.add(poolAmount);
        }

        require(address(this).balance >= amount, "Too little ETH to transfer.");

        (bool success, ) = _rariFundManagerContract.call.value(amount)("");
        require(success, "Failed to transfer ETH to RariFundManager.");

        return true;
    }


    /**
     * @dev Approves tokens to 0x without spending gas on every deposit.
     * @param amount The amount of tokens to be approved.
     * @return Boolean indicating success.
     */
    function approveCompTo0x(uint256 amount) external fundEnabled onlyRebalancer returns (bool) {
        // COMP only
        require(ZeroExExchangeController.approve(COMP_TOKEN, amount), "Approval of tokens to 0x failed.");
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
        if (ethBalance > 0) {
            (bool success, ) = msg.sender.call.value(ethBalance)("");
            require(success, "Failed to transfer ETH.");
        }
        return true;
    }
}
