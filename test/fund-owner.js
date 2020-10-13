const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const fs = require('fs');

const erc20Abi = require('./abi/ERC20.json');

const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");
const RariEthPoolToken = artifacts.require("RariFundToken");

const DummyRariFundController = artifacts.require("DummyRariFundController");
const DummyRariFundManager = artifacts.require("DummyRariFundManager");

// These tests expect the owner and the fund rebalancer of RariFundManager to be set to accounts[0]
contract("RariFundController, RariFundManager", accounts => {
  it("should upgrade the fund manager owner", async () => {
    let fundManagerInstance = await RariFundManager.deployed();

    // RariFundManager.transferOwnership()
    await fundManagerInstance.transferOwnership(accounts[1], { from: accounts[0] });

    // Test disabling and enabling the fund from the new owner address
    await fundManagerInstance.disableFund({ from: accounts[1] });
    await fundManagerInstance.enableFund({ from: accounts[1] });

    // Transfer ownership back
    await fundManagerInstance.transferOwnership(accounts[0], { from: accounts[1] });
  });

  it("should upgrade the fund controller owner", async () => {
    let fundControllerInstance = await RariFundController.deployed();

    // RariFundManager.transferOwnership()
    await fundControllerInstance.transferOwnership(accounts[1], { from: accounts[0] });

    // Test disabling and enabling the fund from the new owner address
    await fundControllerInstance.disableFund({ from: accounts[1] });
    await fundControllerInstance.enableFund({ from: accounts[1] });

    // Transfer ownership back
    await fundControllerInstance.transferOwnership(accounts[0], { from: accounts[1] });
  });

  it("should disable and re-enable the fund", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await RariFundManager.deployed();
    let fundTokenInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariEthPoolToken.at(process.env.UPGRADE_FUND_TOKEN) : RariEthPoolToken.deployed());

    // Disable the fund (via RariFundController and RariFundManager)
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // TODO: Check _fundDisabled (no way to do this as of now)
    
    // Use ETH to deposit/withdraw
    var amountBN = web3.utils.toBN(1e18); // 1 ETH
    
    // Test disabled RariFundManager: make sure we can't deposit or withdraw now (using DAI as an example)
    // var erc20Contract = new web3.eth.Contract(erc20Abi, currencies[currencyCode].tokenAddress);
    // await erc20Contract.methods.approve(RariFundManager.address, amountBN.toString()).send({ from: accounts[0] });
  
    try {
      await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });
      assert.fail();
    } catch (error) {
      assert.include(error.message, "This fund manager contract is disabled. This may be due to an upgrade.");
    }
    
    await fundTokenInstance.approve(RariFundManager.address, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    
    try {
      await fundManagerInstance.withdraw(amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
      assert.fail();
    } catch (error) {
      assert.include(error.message, "This fund manager contract is disabled. This may be due to an upgrade.");
    }

    // Test disabled RariFundController: make sure we can't approve to pools now (using WETH on dYdX as an example)
    try {
      await fundControllerInstance.approveWethToDydxPool(amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
      assert.fail();
    } catch (error) {
      assert.include(error.message, "This fund controller contract is disabled. This may be due to an upgrade.");
    }

    // Re-enable the fund (via RariFundManager and RariFundController)
    await fundManagerInstance.enableFund({ from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    await fundControllerInstance.enableFund({ from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // TODO: Check _fundDisabled (no way to do this as of now)
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

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
    let fundManagerInstance = await RariFundManager.deployed();

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
  it("should put upgrade the FundManager to a copy of its code by disabling the FundController and old FundManager and passing data to the new FundManager", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await RariFundManager.deployed();

    // Approve and deposit tokens to the fund (using DAI as an example)
    var amountBN = web3.utils.toBN(10 ** (18));
    // var erc20Contract = new web3.eth.Contract(erc20Abi, currencies["DAI"].tokenAddress);
    // await erc20Contract.methods.approve(RariFundManager.address, amountBN.toString()).send({ from: accounts[0] });
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Approve and deposit to pool (using Compound as an example)
    // await fundControllerInstance.approveToPool(1, amountBN, { from: accounts[0] });
    await fundControllerInstance.depositToPool(1, amountBN, { from: accounts[0] });

    // Check balance of original FundManager
    var oldRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    var oldFundBalance = await fundManagerInstance.getFundBalance.call();
    var oldAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);

    // Disable FundController and original FundManager
    await fundControllerInstance.disableFund({ from: accounts[0] });
    await fundManagerInstance.disableFund({ from: accounts[0] });

    // TODO: Check _fundDisabled (no way to do this as of now)

    // Create new FundManager
    var newFundManagerInstance = await upgradeProxy(RariFundManager.address, RariFundManager, { unsafeAllowCustomTypes: true });

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
  it("should put upgrade the FundManager to new code by disabling the FundController and old FundManager and passing data to the new FundManager", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await RariFundManager.deployed();
    
    // Approve and deposit tokens to the fund (using DAI as an example)
    var amountBN = web3.utils.toBN(10 ** (18));
    // var erc20Contract = new web3.eth.Contract(erc20Abi, currencies["DAI"].tokenAddress);
    // await erc20Contract.methods.approve(RariFundManager.address, amountBN.toString()).send({ from: accounts[0] });
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Approve and deposit to pool (using Compound as an example)
    // await fundControllerInstance.approveToPool(1, "DAI", amountBN, { from: accounts[0] });
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
    let fundManagerInstance = await RariFundManager.deployed();
    
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    // Approve and deposit tokens to the fund (using DAI as an example)
    var amountBN = web3.utils.toBN(10 ** (18));
    // var erc20Contract = new web3.eth.Contract(erc20Abi, currencies["DAI"].tokenAddress);
    // await erc20Contract.methods.approve(RariFundManager.address, amountBN.toString()).send({ from: accounts[0] });
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Approve and deposit to pool (using Compound as an example)
    // await fundControllerInstance.approveToPool(1, "DAI", amountBN, { from: accounts[0] });
    await fundControllerInstance.depositToPool(1, amountBN, { from: accounts[0] });

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
    let fundManagerInstance = await RariFundManager.deployed();
    
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    var amountBN = web3.utils.toBN(1e18);
    
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Approve and deposit to pool (using Compound as an example)
    // await fundControllerInstance.approveToPool(1, "DAI", amountBN, { from: accounts[0] });
    await fundControllerInstance.depositToPool(1, amountBN, { from: accounts[0] });

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

    // Check balance of new FundController
    let newRawFundBalance = await fundManagerInstance.getRawFundBalance.call();
    assert(newRawFundBalance.gte(oldRawFundBalance));
    let newFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(newFundBalance.gte(oldFundBalance));
    let newAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    assert(newAccountBalance.gte(oldAccountBalance));
  });
});
