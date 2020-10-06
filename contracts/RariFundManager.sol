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
 * This file includes the Ethereum contract code for RariFundManager, the primary contract powering Rari Capital's RariFund.
 */

pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/drafts/SignedSafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

import "@0x/contracts-exchange-libs/contracts/src/LibOrder.sol";
import "@0x/contracts-erc20/contracts/src/interfaces/IEtherToken.sol";

import "./RariFundController.sol";
import "./RariFundToken.sol";
import "./RariFundProxy.sol";

/**
 * @title RariFundManager
 * @dev This contract is the primary contract powering RariFund.
 * Anyone can deposit to the fund with deposit(uint256 amount).
 * Anyone can withdraw their funds (with interest) from the fund with withdraw(uint256 amount).
 */
contract RariFundManager is Ownable {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using SafeERC20 for IERC20;

    /**
     * @dev Boolean that, if true, disables the primary functionality of this RariFundManager.
     */
    bool private _fundDisabled;

    /**
     * @dev Address of the RariFundController.
     */
    address payable private _rariFundControllerContract;

    /**
     * @dev Contract of the RariFundController.
     */
    RariFundController private _rariFundController;

    /**
     * @dev Address of the REFT tokem.
     */
    address private _rariEthFundTokenContract;

    /**
     * @dev Contract for the REFT tokem.
     */
    RariFundToken private _rariEthFundToken;

    /**
     * @dev Address of the RariFundProxy.
     */
    address private _rariFundProxyContract;

    /**
     * @dev Address of the rebalancer.
     */
    address private _rariFundRebalancerAddress;


    /**
     * @dev Supported pools
     */
    uint8[] private _supportedPools;


    /**
     * @dev Constructor that sets supported ERC20 token contract addresses and supported pools for each supported token.
     */
    constructor () public {
        // Add supported currencies
        addPool(0); // dYdX
        addPool(1); // Compound
        addPool(2); // KeeperDAO
    }


    /**
     * @dev Entry into deposit functionality.
     */
    function () external payable {
        require(msg.value > 0, "Not enough money deposited.");
        require(_depositTo(msg.sender, msg.value), "Deposit failed.");
    }

    /**
     * @dev Adds a supported pool for eth.
     * @param pool Pool ID to be supported.
     */
    function addPool(uint8 pool) internal {
        _supportedPools.push(pool);
    }

    /**
     * @dev Emitted when RariFundManager is upgraded.
     */
    event FundManagerUpgraded(address newContract);

    /**
     * @dev Upgrades RariFundManager.
     * Sends data to the new contract, sets the new rETH minter, and forwards eth from the old to the new.
     * @param newContract The address of the new RariFundManager contract.
     */
    function upgradeFundManager(address payable newContract) external onlyOwner {
        // Pass data to the new contract
        FundManagerData memory data;

        data = FundManagerData(
            _netDeposits,
            _rawInterestAccruedAtLastFeeRateChange,
            _interestFeesGeneratedAtLastFeeRateChange,
            _interestFeesClaimed
        );

        RariFundManager(newContract).setFundManagerData(data);

        // Update rETH minter
        if (_rariEthFundTokenContract != address(0)) {
            _rariEthFundToken.addMinter(newContract);
            _rariEthFundToken.renounceMinter();
        }

        emit FundManagerUpgraded(newContract);
    }

    /**
     * @dev Old RariFundManager contract authorized to migrate its data to the new one.
     */
    address payable private _authorizedFundManagerDataSource;

    /**
     * @dev Upgrades RariFundManager.
     * Authorizes the source for fund manager data (i.e., the old fund manager).
     * @param authorizedFundManagerDataSource Authorized source for data (i.e., the old fund manager).
     */
    function authorizeFundManagerDataSource(address payable authorizedFundManagerDataSource) external onlyOwner {
        _authorizedFundManagerDataSource = authorizedFundManagerDataSource;
    }

    /**
     * @dev Struct for data to transfer from the old RariFundManager to the new one.
     */
    struct FundManagerData {
        int256 netDeposits;
        int256 rawInterestAccruedAtLastFeeRateChange;
        int256 interestFeesGeneratedAtLastFeeRateChange;
        uint256 interestFeesClaimed;
    }

    /**
     * @dev Upgrades RariFundManager.
     * Sets data receieved from the old contract.
     * @param data The data from the old contract necessary to initialize the new contract.
     */
    function setFundManagerData(FundManagerData calldata data) external {
        require(_authorizedFundManagerDataSource != address(0) && msg.sender == _authorizedFundManagerDataSource, "Caller is not an authorized source.");
        _netDeposits = data.netDeposits;
        _rawInterestAccruedAtLastFeeRateChange = data.rawInterestAccruedAtLastFeeRateChange;
        _interestFeesGeneratedAtLastFeeRateChange = data.interestFeesGeneratedAtLastFeeRateChange;
        _interestFeesClaimed = data.interestFeesClaimed;
        _interestFeeRate = RariFundManager(_authorizedFundManagerDataSource).getInterestFeeRate();
    }

    /**
     * @dev Emitted when the RariFundController of the RariFundManager is set or upgraded.
     */
    event FundControllerSet(address newContract);

    /**
     * @dev Sets or upgrades RariFundController by forwarding ETH from the old to the new.
     * @param newContract The address of the new RariFundController contract.
     */
    function setFundController(address payable newContract) external onlyOwner {
        // Forward tokens to new FundController if we are upgrading an existing one
        if (_rariFundControllerContract != address(0)) {
            for (uint256 i = 0; i < _supportedPools.length; i++) {
                if (getPoolBalance(_supportedPools[i]) > 0)
                    _rariFundController.withdrawAllFromPoolOnUpgrade(_supportedPools[i]); // No need to update the cached dYdX balances as they won't be used again

                uint256 balance = address(this).balance;
                
                if (balance > 0) newContract.transfer(balance);
            }
        }

        // Set new contract address
        _rariFundControllerContract = newContract;
        _rariFundController = RariFundController(_rariFundControllerContract);
        emit FundControllerSet(newContract);
    }

    /**
     * @dev Forwards ETH in the fund manager to the fund controller (for upgrading from v1.0.0 and for accidental transfers to the fund manager).
     */
    function forwardToFundController() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance > 0) _rariFundControllerContract.transfer(balance);
    }

    /**
     * @dev Emitted when the rETH contract of the RariFundManager is set.
     */
    event FundTokenSet(address newContract);

    /**
     * @dev Sets or upgrades the RariFundToken of the RariFundManager.
     * @param newContract The address of the new RariFundToken contract.
     */
    function setFundToken(address newContract) external onlyOwner {
        _rariEthFundTokenContract = newContract;
        _rariEthFundToken = RariFundToken(_rariEthFundTokenContract);
        emit FundTokenSet(newContract);
    }

    /**
     * @dev Throws if called by any account other than the RariFundToken.
     */
    modifier onlyToken() {
        require(_rariEthFundTokenContract == msg.sender, "Caller is not the RariFundToken.");
        _;
    }


    /**
     * @dev Emitted when the RariFundProxy of the RariFundManager is set.
     */
    event FundProxySet(address newContract);

    /**
     * @dev Sets or upgrades the RariFundProxy of the RariFundManager.
     * @param newContract The address of the new RariFundProxy contract.
     */
    function setFundProxy(address newContract) external onlyOwner {
        _rariFundProxyContract = newContract;
        emit FundProxySet(newContract);
    }

    /**
     * @dev Throws if called by any account other than the RariFundProxy.
     */
    modifier onlyProxy() {
        require(_rariFundProxyContract == msg.sender, "Caller is not the RariFundProxy.");
        _;
    }

    /**
     * @dev Emitted when the rebalancer of the RariFundManager is set.
     */
    event FundRebalancerSet(address newAddress);

    /**
     * @dev Sets or upgrades the rebalancer of the RariFundManager.
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
     * @dev Emitted when the primary functionality of this RariFundManager contract has been disabled.
     */
    event FundDisabled();

    /**
     * @dev Emitted when the primary functionality of this RariFundManager contract has been enabled.
     */
    event FundEnabled();

    /**
     * @dev Disables primary functionality of this RariFundManager so contract(s) can be upgraded.
     */
    function disableFund() external onlyOwner {
        require(!_fundDisabled, "Fund already disabled.");
        _fundDisabled = true;
        emit FundDisabled();
    }

    /**
     * @dev Enables primary functionality of this RariFundManager once contract(s) are upgraded.
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
        require(!_fundDisabled, "This fund manager contract is disabled. This may be due to an upgrade.");
        _;
    }

    /**
     * @dev Boolean indicating if return values of `getPoolBalance` are to be cached.
     */
    bool _cachePoolBalance = false;

    /**
     * @dev Maps cached pool balances to pool indexes
     */
    mapping(uint8 => uint256) _poolBalanceCache;


    /**
     * @dev Returns the fund controller's balance of the specified currency in the specified pool.
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `CompoundPoolController.getBalance`) potentially modifies the state.
     * @param pool The index of the pool.
     */
    function getPoolBalance(uint8 pool) internal returns (uint256) {
        if (!_rariFundController.hasETHInPool(pool)) return 0;

        if (_cachePoolBalance) {
                if (_poolBalanceCache[pool] == 0) _poolBalanceCache[pool] = _rariFundController._getPoolBalance(pool);
                return _poolBalanceCache[pool];
        }

        return _rariFundController._getPoolBalance(pool);
    }


    /**
     * @dev Caches return value of `getPoolBalance` for the duration of the function.
     */
    modifier cachePoolBalance() {
        bool cacheSetPreviously = _cachePoolBalance;
        _cachePoolBalance = true;
        _;

        if (!cacheSetPreviously) {
            _cachePoolBalance = false;

            for (uint256 i = 0; i < _supportedPools.length; i++) {
                _poolBalanceCache[_supportedPools[i]] = 0;
            }
        }
    }

    /**
     * @notice Returns the fund's raw total balance (all REFT holders' funds + all unclaimed fees).
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `RariFundController.getPoolBalance`) potentially modifies the state.
     */
    function getRawFundBalance() public returns (uint256) {
        uint256 totalBalance = _rariFundControllerContract.balance; // ETH balance in fund controller contract

        for (uint256 i = 0; i < _supportedPools.length; i++)
            totalBalance = totalBalance.add(getPoolBalance(_supportedPools[i]));

        return totalBalance;
    }

    /**
     * @dev Caches the fund's raw total balance (all REFT holders' funds + all unclaimed fees) of ETH.
     */
    int256 private _rawFundBalanceCache = -1;


    /**
     * @dev Caches the value of getRawFundBalance() for the duration of the function.
     */
    modifier cacheRawFundBalance() {
        bool cacheSetPreviously = _rawFundBalanceCache >= 0;
        if (!cacheSetPreviously) _rawFundBalanceCache = int256(getRawFundBalance());
        _;
        if (!cacheSetPreviously) _rawFundBalanceCache = -1;
    }

    /**
     * @notice Returns the fund's total investor balance (all REFT holders' funds but not unclaimed fees) of all currencies in USD (scaled by 1e18).
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `getRawFundBalance`) potentially modifies the state.
     */
    function getFundBalance() public cacheRawFundBalance returns (uint256) {
        return getRawFundBalance().sub(getInterestFeesUnclaimed());
    }

    /**
     * @notice Returns an account's total balance in ETH.
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `getRawFundBalance`) potentially modifies the state.
     * @param account The account whose balance we are calculating.
     */
    function balanceOf(address account) external returns (uint256) {
        uint256 reftTotalSupply = _rariEthFundToken.totalSupply();
        if (reftTotalSupply == 0) return 0;
        uint256 reftBalance = _rariEthFundToken.balanceOf(account);
        uint256 fundBalance = getFundBalance();
        uint256 accountBalance = reftBalance.mul(fundBalance).div(reftTotalSupply);
        return accountBalance;
    }

    /**
     * @dev Fund balance limit in ETH per Ethereum address.
     */
    uint256 private _accountBalanceLimitDefault;

    /**
     * @dev Sets or upgrades the default account balance limit in ETH.
     * @param limitEth The default fund balance limit per Ethereum address in ETH.
     */
    function setDefaultAccountBalanceLimit(uint256 limitEth) external onlyOwner {
        _accountBalanceLimitDefault = limitEth;
    }

    /**
     * @dev Maps booleans indicating if Ethereum addresses are immune to the account balance limit.
     */
    mapping(address => int256) private _accountBalanceLimits;

    /**
     * @dev Sets the balance limit in ETH of `account`.
     * @param account The Ethereum address to add or remove.
     * @param limitEth The fund balance limit of `account` in ETH. Use 0 to unset individual limit (and restore account to global limit). Use -1 to disable deposits from `account`.
     */
    function setIndividualAccountBalanceLimit(address account, int256 limitEth) external onlyOwner {
        _accountBalanceLimits[account] = limitEth;
    }


    /**
     * @dev Emitted when funds have been deposited to RariFund.
     */
    event Deposit(address indexed sender, address indexed payee, uint256 amount, uint256 rETHMinted);

    /**
     * @dev Emitted when funds have been withdrawn from RariFund.
     */
    event Withdrawal(address indexed sender, address indexed payee, uint256 amount, uint256 rETHBurned);

    /**
     * @notice Internal function to deposit funds from `msg.sender` to RariFund in exchange for REFT minted to `to`.
     * Please note that you must approve RariFundManager to transfer at least `amount`.
     * @param to The address that will receieve the minted REFT.
     * @param amount The amount of tokens to be deposited.
     * @return Boolean indicating success.
     */
    function _depositTo(address to, uint256 amount) internal fundEnabled returns (bool) {
        // Input validation
        require(amount > 0, "Deposit amount must be greater than 0.");

        // Calculate REFT to mint
        uint256 reftTotalSupply = _rariEthFundToken.totalSupply();
        uint256 fundBalance = reftTotalSupply > 0 ? getFundBalance() : 0; // Only set if used
        
        uint256 reftAmount = 0;

        if (reftTotalSupply > 0 && fundBalance > 0) reftAmount = amount.mul(reftTotalSupply).div(fundBalance);
        else reftAmount = amount;

        require(reftAmount > 0, "Deposit amount is so small that no REFT would be minted.");
        
        // Check account balance limit if `to` is not whitelisted
        require(checkAccountBalanceLimit(to, amount, reftTotalSupply, fundBalance), "Making this deposit would cause the balance of this account to exceed the maximum.");

        // Update net deposits, transfer funds from msg.sender, mint RFT, emit event, and return true
        _netDeposits = _netDeposits.add(int256(amount));

        _rariFundControllerContract.transfer(amount); // Transfer ETH to RariFundController

        require(_rariEthFundToken.mint(to, reftAmount), "Failed to mint output tokens.");

        emit Deposit(msg.sender, to, amount, reftAmount);

        return true;
    }

    /**
     * @dev Checks to make sure that, if `to` is not whitelisted, its balance will not exceed the maximum after depositing `amount`.
     * This function was separated from the `_depositTo` function to avoid the stack getting too deep.
     * @param to The address that will receieve the minted rETH.
     * @param amount The amount of ETH to be deposited.
     * @param reftTotalSupply The total supply of rETH representing the fund's total investor balance.
     * @param fundBalance The fund's total investor balance in (wei).
     * @return Boolean indicating success.
     */
    function checkAccountBalanceLimit(address to, uint256 amount, uint256 reftTotalSupply, uint256 fundBalance) internal view returns (bool) {
        if (to != owner() && to != _interestFeeMasterBeneficiary) {
            if (_accountBalanceLimits[to] < 0) return false;
            uint256 initialBalance = reftTotalSupply > 0 && fundBalance > 0 ? _rariEthFundToken.balanceOf(to).mul(fundBalance).div(reftTotalSupply) : 0; // double check
            uint256 accountBalanceLimit = _accountBalanceLimits[to] > 0 ? uint256(_accountBalanceLimits[to]) : _accountBalanceLimitDefault;
            if (initialBalance.add(amount) > accountBalanceLimit) return false;
        }

        return true;
    }

    /**
     * @notice Deposits funds to RariFund in exchange for rETH.
     * You may only deposit currencies accepted by the fund (see `isCurrencyAccepted(string currencyCode)`).
     * Please note that you must approve RariFundManager to transfer at least `amount`.
     * @return Boolean indicating success.
     */
    function deposit() payable external returns (bool) {
        require(_depositTo(msg.sender, msg.value), "Deposit failed.");
        return true;
    }

    /**
     * @dev Deposits funds from `msg.sender` (RariFundProxy) to RariFund in exchange for RFT minted to `to`.
     * You may only deposit currencies accepted by the fund (see `isCurrencyAccepted(string currencyCode)`).
     * Please note that you must approve RariFundManager to transfer at least `amount`.
     * @param to The address that will receieve the minted RFT.
     * @return Boolean indicating success.
     */
    function depositTo(address to) payable external onlyProxy returns (bool) {
        require(_depositTo(to, msg.value), "Deposit failed.");
        return true;
    }


    /**
     * @dev Returns the amount of REFT to burn for a withdrawal (used by `_withdrawFrom`).
     * @param from The address from which REFT will be burned.
     * @param amount The amount of the withdrawal in ETH
     */
    function getREFTBurnAmount(address from, uint256 amount) internal returns (uint256) {
        uint256 reftTotalSupply = _rariEthFundToken.totalSupply();
        uint256 fundBalance = getFundBalance();
        require(fundBalance > 0, "Fund balance is zero.");
        uint256 reftAmount = amount.mul(reftTotalSupply).div(fundBalance); // check again
        require(reftAmount <= _rariEthFundToken.balanceOf(from), "Your REFT balance is too low for a withdrawal of this amount.");
        require(reftAmount > 0, "Withdrawal amount is so small that no REFT would be burned.");
        return reftAmount;
    }

    /**
     * @dev Internal function to withdraw funds from RariFund to `msg.sender` in exchange for RFT burned from `from`.
     * Please note that you must approve RariFundManager to burn of the necessary amount of REFT.
     * @param from The address from which REFT will be burned.
     * @param amount The amount of tokens to be withdrawn.
     * @return Boolean indicating success.
     */
    function _withdrawFrom(address from, uint256 amount) internal fundEnabled cachePoolBalance returns (bool) {
        // Input validation
        require(amount > 0, "Withdrawal amount must be greater than 0.");

        // Check contract balance of token and withdraw from pools if necessary
        uint256 contractBalance = _rariFundControllerContract.balance; // get ETH balance

        for (uint256 i = 0; i < _supportedPools.length; i++) {
            if (contractBalance >= amount) break;
            uint8 pool = _supportedPools[i];
            uint256 poolBalance = getPoolBalance(pool);
            if (poolBalance <= 0) continue;
            uint256 amountLeft = amount.sub(contractBalance);
            uint256 poolAmount = amountLeft < poolBalance ? amountLeft : poolBalance;
            require(_rariFundController.withdrawFromPoolKnowingBalanceToManager(pool, poolAmount, poolBalance), "Pool withdrawal failed.");
            _poolBalanceCache[pool] = poolBalance.sub(amount);
            contractBalance = contractBalance.add(poolAmount);
        }

        require(amount <= contractBalance, "Available balance not enough to cover amount even after withdrawing from pools.");

        // Calculate rETH to burn
        uint256 reftAmount = getREFTBurnAmount(from, amount);

        // Burn REFT, transfer funds to msg.sender, update net deposits, emit event, and return true
        _rariEthFundToken.burnFrom(from, reftAmount); // The user must approve the burning of tokens beforehand
        
        // _rariFundControllerContract.withdrawToManager(amount);

        msg.sender.transfer(amount);

        _netDeposits = _netDeposits.sub(int256(amount));

        emit Withdrawal(from, msg.sender, amount, reftAmount);

        return true;
    }

    /**
     * @notice Withdraws funds from RariFund in exchange for rETH.
     * You may only withdraw currencies held by the fund (see `getRawFundBalance(string currencyCode)`).
     * Please note that you must approve RariFundManager to burn of the necessary amount of rETH.
     * @param amount The amount of tokens to be withdrawn.
     * @return Boolean indicating success.
     */
    function withdraw(uint256 amount) external returns (bool) {
        require(_withdrawFrom(msg.sender, amount), "Withdrawal failed.");
        return true;
    }

    /**
     * @dev Withdraws funds from RariFund to `msg.sender` (RariFundProxy) in exchange for RFT burned from `from`.
     * You may only withdraw currencies held by the fund (see `getRawFundBalance(string currencyCode)`).
     * Please note that you must approve RariFundManager to burn of the necessary amount of RFT.
     * @param from The address from which RFT will be burned.
     * @param amount The amount of tokens to be withdrawn.
     * @return Boolean indicating success.
     */
    function withdrawFrom(address from, uint256 amount) external onlyProxy returns (bool) {
        require(_withdrawFrom(from, amount), "Withdrawal failed.");
        return true;
    }

    /**
     * @dev Net quantity of deposits to the fund (i.e., deposits - withdrawals).
     * On deposit, amount deposited is added to `_netDeposits`; on withdrawal, amount withdrawn is subtracted from `_netDeposits`.
     */
    int256 private _netDeposits;
    
    /**
     * @notice Returns the raw total amount of interest accrued by the fund as a whole (including the fees paid on interest) in USD (scaled by 1e18).
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `getRawFundBalance`) potentially modifies the state.
     */
    function getRawInterestAccrued() public returns (int256) {
        return int256(getRawFundBalance()).sub(_netDeposits).add(int256(_interestFeesClaimed));
    }
    
    /**
     * @notice Returns the total amount of interest accrued by past and current RFT holders (excluding the fees paid on interest) in USD (scaled by 1e18).
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `getRawFundBalance`) potentially modifies the state.
     */
    function getInterestAccrued() public returns (int256) {
        return int256(getFundBalance()).sub(_netDeposits);
    }

    /**
     * @dev The proportion of interest accrued that is taken as a service fee (scaled by 1e18).
     */
    uint256 private _interestFeeRate;

    /**
     * @dev Returns the fee rate on interest.
     */
    function getInterestFeeRate() public view returns (uint256) {
        return _interestFeeRate;
    }

    /**
     * @dev Sets the fee rate on interest.
     * @param rate The proportion of interest accrued to be taken as a service fee (scaled by 1e18).
     */
    function setInterestFeeRate(uint256 rate) external fundEnabled onlyOwner cacheRawFundBalance {
        require(rate != _interestFeeRate, "This is already the current interest fee rate.");
        _depositFees();
        _interestFeesGeneratedAtLastFeeRateChange = getInterestFeesGenerated(); // MUST update this first before updating _rawInterestAccruedAtLastFeeRateChange since it depends on it 
        _rawInterestAccruedAtLastFeeRateChange = getRawInterestAccrued();
        _interestFeeRate = rate;
    }

    /**
     * @dev The amount of interest accrued at the time of the most recent change to the fee rate.
     */
    int256 private _rawInterestAccruedAtLastFeeRateChange;

    /**
     * @dev The amount of fees generated on interest at the time of the most recent change to the fee rate.
     */
    int256 private _interestFeesGeneratedAtLastFeeRateChange;

    /**
     * @notice Returns the amount of interest fees accrued by beneficiaries in USD (scaled by 1e18).
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `getRawFundBalance`) potentially modifies the state.
     */
    function getInterestFeesGenerated() public returns (int256) {
        int256 rawInterestAccruedSinceLastFeeRateChange = getRawInterestAccrued().sub(_rawInterestAccruedAtLastFeeRateChange);
        int256 interestFeesGeneratedSinceLastFeeRateChange = rawInterestAccruedSinceLastFeeRateChange.mul(int256(_interestFeeRate)).div(1e18);
        int256 interestFeesGenerated = _interestFeesGeneratedAtLastFeeRateChange.add(interestFeesGeneratedSinceLastFeeRateChange);
        return interestFeesGenerated;
    }

    /**
     * @dev The total claimed amount of interest fees.
     */
    uint256 private _interestFeesClaimed;

    /**
     * @dev Returns the total unclaimed amount of interest fees.
     * Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `getRawFundBalance`) potentially modifies the state.
     */
    function getInterestFeesUnclaimed() public returns (uint256) {
        int256 interestFeesUnclaimed = getInterestFeesGenerated().sub(int256(_interestFeesClaimed));
        return interestFeesUnclaimed > 0 ? uint256(interestFeesUnclaimed) : 0;
    }

    /**
     * @dev The master beneficiary of fees on interest; i.e., the recipient of all fees on interest.
     */
    address payable private _interestFeeMasterBeneficiary;

    /**
     * @dev Sets the master beneficiary of interest fees.
     * @param beneficiary The master beneficiary of fees on interest; i.e., the recipient of all fees on interest.
     */
    function setInterestFeeMasterBeneficiary(address payable beneficiary) external fundEnabled onlyOwner {
        require(beneficiary != address(0), "Master beneficiary cannot be the zero address.");
        _interestFeeMasterBeneficiary = beneficiary;
    }

    /**
     * @dev Emitted when fees on interest are deposited back into the fund.
     */
    event InterestFeeDeposit(address beneficiary, uint256 amount);

    /**
     * @dev Emitted when fees on interest are withdrawn.
     */
    event InterestFeeWithdrawal(address beneficiary, uint256 amountEth);

    /**
     * @dev Internal function to deposit all accrued fees on interest back into the fund on behalf of the master beneficiary.
     * @return Integer indicating success (0), no fees to claim (1), or no REFT to mint (2).
     */
    function _depositFees() internal fundEnabled cacheRawFundBalance returns (uint8) {
        require(_interestFeeMasterBeneficiary != address(0), "Master beneficiary cannot be the zero address.");

        uint256 amount = getInterestFeesUnclaimed();
        if (amount <= 0) return 1;

        uint256 reftTotalSupply = _rariEthFundToken.totalSupply();
        uint256 reftAmount = 0;

        if (reftTotalSupply > 0) {
            uint256 fundBalance = getFundBalance();
            if (fundBalance > 0) reftAmount = amount.mul(reftTotalSupply).div(fundBalance);
            else reftAmount = amount;
        } else reftAmount = amount;

        if (reftAmount <= 0) return 2;

        _interestFeesClaimed = _interestFeesClaimed.add(amount);
        _netDeposits = _netDeposits.add(int256(amount));

        require(_rariEthFundToken.mint(_interestFeeMasterBeneficiary, reftAmount), "Failed to mint output tokens.");
        emit Deposit(_interestFeeMasterBeneficiary, _interestFeeMasterBeneficiary, amount, reftAmount);

        emit InterestFeeDeposit(_interestFeeMasterBeneficiary, amount);
        return 0;
    }

    /**
     * @notice Deposits all accrued fees on interest back into the fund on behalf of the master beneficiary.
     * @return Boolean indicating success.
     */
    function depositFees() external onlyRebalancer returns (bool) {
        uint8 result = _depositFees();
        require(result == 0, result == 2 ? "Deposit amount is so small that no REFT would be minted." : "No new fees are available to claim.");
    }

    /**
     * @notice Withdraws all accrued fees on interest to the master beneficiary.
     * @return Boolean indicating success.
     */
    function withdrawFees() external fundEnabled onlyRebalancer returns (bool) {
        require(_interestFeeMasterBeneficiary != address(0), "Master beneficiary cannot be the zero address.");

        uint256 amount = getInterestFeesUnclaimed();

        require(amount > 0, "No new fees are available to claim.");

        _interestFeesClaimed = _interestFeesClaimed.add(amount);
        _rariFundController.withdrawToManager(amount);
        _interestFeeMasterBeneficiary.transfer(amount);

        emit InterestFeeWithdrawal(_interestFeeMasterBeneficiary, amount);
        return true;
    }
}
