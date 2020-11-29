/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

const erc20Abi = require('./abi/ERC20.json');

const pools = require('./fixtures/pools.json');

const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");

if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) {
  RariFundController.address = process.env.UPGRADE_FUND_CONTROLLER_ADDRESS;
  RariFundManager.address = process.env.UPGRADE_FUND_MANAGER_ADDRESS;
}

contract("RariFundController, RariFundManager", accounts => {
  it("should deposit to the fund, approve deposits to dYdX with weth, and deposit to pools via RariFundController.depositToPool", async () => {
    let fundControllerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundController.at(process.env.UPGRADE_FUND_CONTROLLER_ADDRESS) : RariFundController.deployed());
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    // Approve WETH to dYdX and kEther to KeeperDAO
    await fundControllerInstance.approveWethToDydxPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    var amountBN = web3.utils.toBN(1e18);

    for (const pool of [0, 1, 2, 3]) {
      // Check initial pool balance
      var initialBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      await fundManagerInstance.deposit({from: process.env.DEVELOPMENT_ADDRESS, value: amountBN});
      // Deposit to pool
      await fundControllerInstance.depositToPool(pool, amountBN, { from: process.env.DEVELOPMENT_ADDRESS });
      // Check new pool balance
      // Accounting for the possibility of a pool losing some dust using amountBN.mul(9999).div(10000)
      var postDepositBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      assert(postDepositBalanceOfUnderlying.gte(initialBalanceOfUnderlying.add(amountBN.mul(web3.utils.toBN(9999)).div(web3.utils.toBN(10000)))));
    }
  });

  it("should withdraw half from all pools via RariFundController.withdrawFromPool", async () => {
    let fundControllerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundController.at(process.env.UPGRADE_FUND_CONTROLLER_ADDRESS) : RariFundController.deployed());

    var amountBN = web3.utils.toBN(1e18);

    for (const pool of [0, 1, 2, 3]) {
      // Check initial pool balance
      var oldBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      // TODO: Ideally, we add actually call rari-fund-rebalancer
      console.log("Withdrawing half from ", pool);
      await fundControllerInstance.withdrawFromPool(pool, amountBN.div(web3.utils.toBN(2)), { from: process.env.DEVELOPMENT_ADDRESS });
      // Check new pool balance
      var newBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      assert(newBalanceOfUnderlying.lt(oldBalanceOfUnderlying));
    }
  });

  it("should withdraw everything from all pools via RariFundController.withdrawAllFromPool", async () => {
    let fundControllerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundController.at(process.env.UPGRADE_FUND_CONTROLLER_ADDRESS) : RariFundController.deployed());
    
    // For each currency of each pool:
    for (const pool of [0, 1, 2, 3]) {
      // TODO: Ideally, we add actually call rari-fund-rebalancer
      await fundControllerInstance.withdrawAllFromPool(pool, { from: process.env.DEVELOPMENT_ADDRESS, nonce: await web3.eth.getTransactionCount(process.env.DEVELOPMENT_ADDRESS) });
      // Check new pool balance
      var newBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      assert(newBalanceOfUnderlying.isZero());
    }
  });
});