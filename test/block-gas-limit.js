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

if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) {
  RariFundManager.address = process.env.UPGRADE_FUND_MANAGER_ADDRESS;
}

const AlphaPoolController = artifacts.require("AlphaPoolController");
const MockEnzymeComptroller = artifacts.require("MockEnzymeComptroller");

// These tests expect the owner and the fund rebalancer of RariFundManager to be set to accounts[0]
contract("RariFundController", async accounts => {
  if (!process.env.ENZYME_COMPTROLLER) {
    let fundControllerInstance = await RariFundController.deployed();
    var alphaPoolControllerLibrary = await AlphaPoolController.new({ from: process.env.DEVELOPMENT_ADDRESS });
    await MockEnzymeComptroller.link("AlphaPoolController", alphaPoolControllerLibrary.address);
    var mockEnzymeComptrollerInstance = await MockEnzymeComptroller.new({ from: process.env.DEVELOPMENT_ADDRESS });
    await fundControllerInstance.setEnzymeComptroller(mockEnzymeComptrollerInstance.address);
  }

  it("should put upgrade the FundController with funds in all pools without using too much gas", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    // Check balance before deposits
    let oldRawFundBalance = await fundManagerInstance.getRawFundBalance.call();

    // Tally up ETH deposited
    var totalEthBN = web3.utils.toBN(5e18);
    
    // For each currency of each pool, deposit to fund and deposit to pool
    var amountBN = web3.utils.toBN(1e18);

    // approve WETH to dYdX for deposits and approve kEther to be burned by KeeperDAO
    await fundControllerInstance.approveWethToPool(0, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    // deposit 4 ETH
    await fundManagerInstance.deposit({ from: accounts[0], value: totalEthBN });
    
    for (var pool = 0; pool < Object.keys(pools).length; pool++) {
        // deeposit 1 ETH to each pool
        await fundControllerInstance.depositToPool(pool, amountBN, { from: accounts[0] });
    }

    // Disable original FundController and FundManager
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // Create new FundController and set its FundManager
    var newFundControllerInstance = await RariFundController.new({ from: accounts[0] });
    await newFundControllerInstance.setFundManager(RariFundManager.address, { from: accounts[0] });

    // Upgrade!
    var result = await fundControllerInstance.upgradeFundController(newFundControllerInstance.address, { from: process.env.DEVELOPMENT_ADDRESS });
    console.log("Gas usage of RariFundController.upgradeFundController:", result.receipt.gasUsed);
    
    // Assert it uses no more than 5 million gas
    assert.isAtMost(result.receipt.gasUsed, 5000000);

    // Set new FundController address
    await fundManagerInstance.setFundController(newFundControllerInstance.address, { from: accounts[0] });

    // Re-enable fund manager
    await fundManagerInstance.enableFund({ from: accounts[0] });

    // Check balance of fund with upgraded FundController, accounting for dust lost in conversions
    let newRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    let keeperDaoDepositFeeBN = amountBN.muln(64).divn(10000);
    assert(newRawFundBalance.gte(oldRawFundBalance.add(totalEthBN.sub(keeperDaoDepositFeeBN).mul(web3.utils.toBN(9999)).div(web3.utils.toBN(10000)))));
  });
});
