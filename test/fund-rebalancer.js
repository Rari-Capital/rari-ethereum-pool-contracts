// SPDX-License-Identifier: UNLICENSED
const erc20Abi = require('./abi/ERC20.json');

const pools = require('./fixtures/pools.json');

const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");

if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) {
  RariFundManager.address = process.env.UPGRADE_FUND_MANAGER_ADDRESS;
}

const AlphaPoolController = artifacts.require("AlphaPoolController");
const MockEnzymeComptroller = artifacts.require("MockEnzymeComptroller");

contract("RariFundController, RariFundManager", async accounts => {
  if (!process.env.ENZYME_COMPTROLLER) {
    let fundControllerInstance = await RariFundController.deployed();
    var alphaPoolControllerLibrary = await AlphaPoolController.new({ from: process.env.DEVELOPMENT_ADDRESS });
    await MockEnzymeComptroller.link("AlphaPoolController", alphaPoolControllerLibrary.address);
    var mockEnzymeComptrollerInstance = await MockEnzymeComptroller.new({ from: process.env.DEVELOPMENT_ADDRESS });
    await fundControllerInstance.setEnzymeComptroller(mockEnzymeComptrollerInstance.address);
  }

  it("should deposit to the fund, approve deposits to dYdX with weth, and deposit to pools via RariFundController.depositToPool", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());

    // Approve WETH to dYdX and Enzyme and kEther to KeeperDAO
    await fundControllerInstance.approveWethToPool(0, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));
    await fundControllerInstance.approveWethToPool(5, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    var amountBN = web3.utils.toBN(1e18);

    for (const pool of [0, 1, 2, 3, 4, 5]) {
      // Check initial pool balance
      var initialBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      await fundManagerInstance.deposit({from: process.env.DEVELOPMENT_ADDRESS, value: amountBN});
      // Deposit to pool
      await fundControllerInstance.depositToPool(pool, amountBN, { from: process.env.DEVELOPMENT_ADDRESS });
      // Check new pool balance
      // Accounting for KeeperDAO deposit fee of 0.64%
      // Accounting for the possibility of a pool losing some dust using amountBN.mul(9999).div(10000)
      var postDepositBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      assert(postDepositBalanceOfUnderlying.gte(initialBalanceOfUnderlying.add((pool == 2 ? amountBN.sub(amountBN.muln(64).divn(10000)) : amountBN).mul(web3.utils.toBN(9999)).div(web3.utils.toBN(10000)))));
    }
  });

  it("should withdraw half from all pools via RariFundController.withdrawFromPool", async () => {
    let fundControllerInstance = await RariFundController.deployed();

    var amountBN = web3.utils.toBN(1e18);

    for (const pool of [0, 1, 2, 3, 4, 5]) {
      // Check initial pool balance
      var oldBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      // TODO: Ideally, we add actually call rari-fund-rebalancer
      await fundControllerInstance.withdrawFromPool(pool, amountBN.div(web3.utils.toBN(2)), { from: process.env.DEVELOPMENT_ADDRESS });
      // Check new pool balance
      var newBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      assert(newBalanceOfUnderlying.lt(oldBalanceOfUnderlying));
    }
  });

  it("should withdraw everything from all pools via RariFundController.withdrawAllFromPool", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    
    // For each currency of each pool:
    for (const pool of [0, 1, 2, 3, 4, 5]) {
      // TODO: Ideally, we add actually call rari-fund-rebalancer
      await fundControllerInstance.withdrawAllFromPool(pool, { from: process.env.DEVELOPMENT_ADDRESS, nonce: await web3.eth.getTransactionCount(process.env.DEVELOPMENT_ADDRESS) });
      // Check new pool balance
      var newBalanceOfUnderlying = await fundControllerInstance.getPoolBalance.call(pool);
      assert(newBalanceOfUnderlying.isZero());
    }
  });
});