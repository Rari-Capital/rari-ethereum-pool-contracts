const pools = require('./fixtures/pools.json');

const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");

// These tests expect the owner and the fund rebalancer of RariFundManager to be set to accounts[0]
contract("RariFundController", accounts => {
  it("should put upgrade the FundController with funds in all pools in all currencies without using too much gas", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await RariFundManager.deployed();

    // Check balance before deposits
    let oldRawFundBalance = await fundManagerInstance.getRawFundBalance.call();

    // Tally up ETH deposited
    var totalEthBN = web3.utils.toBN(0);
    
    // For each currency of each pool, deposit to fund and deposit to pool
    var amountBN = web3.utils.toBN(10 ** (18));

    totalEthBN.iadd(web3.utils.toBN(4e18));

    await fundControllerInstance.depositToPool(0, { from: accounts[0], value: amountBN }); // dydx
    await fundControllerInstance.depositToPool(1, { from: accounts[0], value: amountBN }); // comp
    await fundControllerInstance.depositToPool(2, { from: accounts[0], value: amountBN }); // keeperdao
    await fundControllerInstance.depositToPool(3, { from: accounts[0], value: amountBN }); // aave

    // Disable original FundController and FundManager
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // Create new FundController and set its FundManager
    var newFundControllerInstance = await RariFundController.new({ from: accounts[0] });
    await newFundControllerInstance.setFundManager(RariFundManager.address, { from: accounts[0] });

    // Upgrade!
    var result = await fundManagerInstance.setFundController(newFundControllerInstance.address, { from: accounts[0] });
    console.log("Gas usage of RariFundManager.setFundController:", result.receipt.gasUsed);
    assert.isAtMost(result.receipt.gasUsed, 5000000); // Assert it uses no more than 5 million gas

    // Check balance of new FundManager
    let newRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    assert(newRawFundBalance.gte(oldRawFundBalance.add(totalEthBN.mul(web3.utils.toBN(9999)).div(web3.utils.toBN(10000)))));
  });
});
