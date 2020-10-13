/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

const pools = require('./fixtures/pools.json');

const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");

// These tests expect the owner and the fund rebalancer of RariFundManager to be set to accounts[0]
contract("RariFundController", accounts => {
  it("should put upgrade the FundController with funds in all pools without using too much gas", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await RariFundManager.deployed();

    // Check balance before deposits
    let oldRawFundBalance = await fundManagerInstance.getRawFundBalance.call();

    // Tally up ETH deposited
    var totalEthBN = web3.utils.toBN(0);
    
    // For each currency of each pool, deposit to fund and deposit to pool
    var amountBN = web3.utils.toBN(1e18);

    await fundControllerInstance.approveWethToDydxPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    await fundManagerInstance.deposit({ from: accounts[0], value: web3.utils.toBN(4e18) });
    
    await fundControllerInstance.depositToPool(0, amountBN, { from: accounts[0] }); // dydx
    await fundControllerInstance.depositToPool(1, amountBN, { from: accounts[0] }); // comp
    await fundControllerInstance.depositToPool(2, amountBN, { from: accounts[0] }); // keeperdao
    await fundControllerInstance.depositToPool(3, amountBN, { from: accounts[0] }); // aave
    
    totalEthBN.iadd(web3.utils.toBN(4e18));

    // Disable original FundController and FundManager
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // Create new FundController and set its FundManager
    var newFundControllerInstance = await RariFundController.new({ from: accounts[0] });
    await newFundControllerInstance.setFundManager(RariFundManager.address, { from: accounts[0] });

    // Upgrade!
    var result = await fundControllerInstance.upgradeFundController(newFundControllerInstance.address, { from: process.env.DEVELOPMENT_ADDRESS });

    console.log("Gas usage of RariFundController.upgradeFundController:", result.receipt.gasUsed);
    assert.isAtMost(result.receipt.gasUsed, 5000000); // Assert it uses no more than 5 million gas

    await fundManagerInstance.setFundController(newFundControllerInstance.address, { from: accounts[0] });

    // Check balance of new FundManager
    let newRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    console.log("New fund balance: ", newRawFundBalance.toString(10));

    assert(newRawFundBalance.gte(oldRawFundBalance.add(totalEthBN.mul(web3.utils.toBN(9999)).div(web3.utils.toBN(10000)))));
  });
});
