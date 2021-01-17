/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const fs = require('fs');

const erc20Abi = require('./abi/ERC20.json');

const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");
const RariFundToken = artifacts.require("RariFundToken");

if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) {
  RariFundManager.address = process.env.UPGRADE_FUND_MANAGER_ADDRESS;
  RariFundToken.address = process.env.UPGRADE_FUND_TOKEN_ADDRESS;
}

const DummyRariFundController = artifacts.require("DummyRariFundController");
const DummyRariFundManager = artifacts.require("DummyRariFundManager");

// These tests expect the owner and the fund rebalancer of RariFundManager to be set to accounts[0]
contract("RariFundController, RariFundManager", accounts => {
  it("should upgrade the fund manager owner", async () => {
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    await fundManagerInstance.transferOwnership(accounts[1], { from: accounts[0] });

    // Test disabling and enabling the fund from the new owner address
    await fundManagerInstance.disableFund({ from: accounts[1] });
    await fundManagerInstance.enableFund({ from: accounts[1] });

    // Transfer ownership back
    await fundManagerInstance.transferOwnership(accounts[0], { from: accounts[1] });
  });

  it("should upgrade the fund controller owner", async () => {
    let fundControllerInstance = await RariFundController.deployed();

    await fundControllerInstance.transferOwnership(accounts[1], { from: accounts[0] });

    // Test disabling and enabling the fund from the new owner address
    await fundControllerInstance.disableFund({ from: accounts[1] });
    await fundControllerInstance.enableFund({ from: accounts[1] });

    // Transfer ownership back
    await fundControllerInstance.transferOwnership(accounts[0], { from: accounts[1] });
  });

  it("should disable and re-enable the fund", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());
    let fundTokenInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundToken.at(process.env.UPGRADE_FUND_TOKEN_ADDRESS) : RariFundToken.deployed());

    // Disable the RariFundController and RariFundManager
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // TODO: Check _fundDisabled (no way to do this as of now)
    
    var amountBN = web3.utils.toBN(1e18);
    
    // Test disabled RariFundManager: make sure we can't deposit or withdraw now
    try {
      await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });
      assert.fail();
    } catch (error) {
      assert.include(error.message, "This fund manager contract is disabled. This may be due to an upgrade.");
    }
        
    try {
      await fundManagerInstance.withdraw(amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
      assert.fail();
    } catch (error) {
      assert.include(error.message, "This fund manager contract is disabled. This may be due to an upgrade.");
    }

    // Test disabled RariFundController: make sure we can't approve to pools now (using WETH on dYdX as an example)
    try {
      await fundControllerInstance.approveWethToPool(0, amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
      assert.fail();
    } catch (error) {
      assert.include(error.message, "This fund controller contract is disabled. This may be due to an upgrade.");
    }

    // Re-enable the fund (via RariFundManager and RariFundController)
    await fundManagerInstance.enableFund({ from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    await fundControllerInstance.enableFund({ from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // TODO: Check _fundDisabled (no way to do this as of now)

    // Test re-enabled RariFundManager: make sure we can deposit and withdraw now
    let myInitialBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    await fundManagerInstance.deposit({ from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]), value: amountBN });
    let myPostDepositBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    assert(myPostDepositBalance.gte(myInitialBalance.add(amountBN)));
    await fundTokenInstance.approve(RariFundManager.address, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    await fundManagerInstance.withdraw(amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    let myPostWithdrawalBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    assert(myPostWithdrawalBalance.lt(myPostDepositBalance));
  });

  it("should put upgrade the fund rebalancer", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    // Set fund rebalancer addresses
    await fundControllerInstance.setFundRebalancer(accounts[1], { from: accounts[0] });
    await fundManagerInstance.setFundRebalancer(accounts[1], { from: accounts[0] });

    // TODO: Check RariFundManager._rariFundRebalancerAddress (no way to do this as of now)

    // Test fund rebalancer functions from the second account via RariFundManager and RariFundController
    // TODO: Ideally, we actually test the fund rebalancer itself

    // Reset fund rebalancer addresses
    await fundManagerInstance.setFundRebalancer(accounts[0], { from: accounts[0] });
    await fundControllerInstance.setFundRebalancer(accounts[0], { from: accounts[0] });
  });
});

contract("RariFundManager", accounts => {
  it("should upgrade the FundManager implementation to a copy of its code", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    //Approve WETH to dYdX
    await fundControllerInstance.approveWethToPool(0, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    // Deposit ETH to the fund
    var amountBN = web3.utils.toBN(1e18);
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Approve and deposit to pool (using dYdX as an example)
    await fundControllerInstance.depositToPool(0, amountBN, { from: accounts[0] });

    // Check balance of original FundManager
    var oldRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    var oldFundBalance = await fundManagerInstance.getFundBalance.call();
    var oldAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);

    // Upgrade FundManager
    if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) RariFundManager.class_defaults.from = process.env.UPGRADE_FUND_OWNER_ADDRESS;
    var newFundManagerInstance = await upgradeProxy(RariFundManager.address, RariFundManager, { unsafeAllowCustomTypes: true });
    if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) RariFundManager.class_defaults.from = process.env.DEVELOPMENT_ADDRESS;

    // Check balance of new FundManager
    let newRawFundBalance = await newFundManagerInstance.getRawFundBalance.call();
    assert(newRawFundBalance.gte(oldRawFundBalance));
    let newFundBalance = await newFundManagerInstance.getFundBalance.call();
    assert(newFundBalance.gte(oldFundBalance));
    let newAccountBalance = await newFundManagerInstance.balanceOf.call(accounts[0]);
    assert(newAccountBalance.gte(oldAccountBalance));
  });
});

contract("RariFundManager", accounts => {
  it("should upgrade the proxy and implementation of FundManager to new code", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    // Deposit ETH
    var amountBN = web3.utils.toBN(1e18);
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Deposit to pool (using Compound as an example)
    await fundControllerInstance.depositToPool(1, amountBN, { from: accounts[0] });

    // Disable FundController and original FundManager
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // TODO: Check _fundDisabled (no way to do this as of now)

    // Create new FundManager
    var newFundManagerInstance = await deployProxy(DummyRariFundManager, [], { unsafeAllowCustomTypes: true });

    // Upgrade!
    await newFundManagerInstance.authorizeFundManagerDataSource(fundManagerInstance.address, { from: accounts[0] });
    await fundManagerInstance.upgradeFundManager(newFundManagerInstance.address);
    await newFundManagerInstance.authorizeFundManagerDataSource("0x0000000000000000000000000000000000000000", { from: accounts[0] });
  });
});

contract("RariFundController", accounts => {
  it("should put upgrade the FundController to a copy of its code by disabling the old FundController and the FundManager, withdrawing all tokens from all pools, and transferring them to the new FundController", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    // Approve kEther to KeeperDAO contract
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    // Deposit ETH
    var amountBN = web3.utils.toBN(1e18);
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Deposit to pool (using KeeperDAO as an example)
    await fundControllerInstance.depositToPool(2, amountBN, { from: accounts[0] });

    // Check balance of original FundManager
    var oldRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    var oldFundBalance = await fundManagerInstance.getFundBalance.call();
    var oldAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);

    // Disable FundController and original FundManager
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // TODO: Check _fundDisabled (no way to do this as of now)

    // Create new FundController
    var newFundControllerInstance = await RariFundController.new({ from: accounts[0] });
    await newFundControllerInstance.setFundManager(RariFundManager.address, { from: accounts[0] });

    // Upgrade!
    await fundControllerInstance.upgradeFundController(newFundControllerInstance.address, { from: process.env.DEVELOPMENT_ADDRESS });
    await fundManagerInstance.setFundController(newFundControllerInstance.address, { from: accounts[0] });

    // Re-enable fund manager
    await fundManagerInstance.enableFund({ from: accounts[0] });

    // Check balance of new FundController
    let newRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    assert(newRawFundBalance.gte(oldRawFundBalance));
    let newFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(newFundBalance.gte(oldFundBalance));
    let newAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    assert(newAccountBalance.gte(oldAccountBalance));
  });
});

contract("RariFundController", accounts => {
  it("should put upgrade the FundController to new code by disabling the old FundController and the FundManager, withdrawing all ETH from all pools, and transferring them to the new FundController", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    var amountBN = web3.utils.toBN(1e18);
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Approve and deposit to pool (using Aave as an example)
    await fundControllerInstance.depositToPool(3, amountBN, { from: accounts[0] });

    // Check balance of original FundController
    var oldRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    var oldFundBalance = await fundManagerInstance.getFundBalance.call();
    var oldAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);

    // Disable FundController and original FundManager
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // TODO: Check _fundDisabled (no way to do this as of now)

    // Create new FundController
    var newFundControllerInstance = await DummyRariFundController.new({ from: process.env.DEVELOPMENT_ADDRESS });

    // Upgrade!
    await fundControllerInstance.upgradeFundController(newFundControllerInstance.address, { from: process.env.DEVELOPMENT_ADDRESS });
    await fundManagerInstance.setFundController(newFundControllerInstance.address, { from: accounts[0] });

    // Re-enable fund manager
    await fundManagerInstance.enableFund({ from: accounts[0] });

    // Check balance of new FundController
    let newRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    assert(newRawFundBalance.gte(oldRawFundBalance));
    let newFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(newFundBalance.gte(oldFundBalance));
    let newAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    assert(newAccountBalance.gte(oldAccountBalance));
  });
});
