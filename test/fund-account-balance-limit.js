const erc20Abi = require('./abi/ERC20.json');

const RariFundManager = artifacts.require("RariFundManager");
const RariEthFundToken = artifacts.require("RariFundToken");

// The owner of RariFundManager should be set to accounts[0] and accounts[1] should own at least a couple dollars in DAI
contract("RariFundManager", accounts => {
  it("should make deposits until the default (global) account balance limit is hit", async () => {
    let fundManagerInstance = await RariFundManager.deployed();
    let fundTokenInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariEthFundToken.at(process.env.UPGRADE_FUND_TOKEN) : RariEthFundToken.deployed());

    // Get account balance in the fund and withdraw all before we start
    let accountBalance = await fundManagerInstance.balanceOf.call(accounts[1]);

    if (accountBalance.gt(web3.utils.toBN(0))) {
      await fundTokenInstance.approve(RariFundManager.address, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)), { from: accounts[1], nonce: await web3.eth.getTransactionCount(accounts[1]) });
      await fundManagerInstance.withdraw(accountBalance, { from: accounts[1], nonce: await web3.eth.getTransactionCount(accounts[1]) });
    }

    // Set default account balance limit, 1 ETH
    var defaultAccountBalanceLimitEthBN = web3.utils.toBN(1e18);

    await fundManagerInstance.setDefaultAccountBalanceLimit(defaultAccountBalanceLimitEthBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // Use 0.1 ETH as an example for depositing
    var depositAmountBN = web3.utils.toBN(1e17);
    
    // Check account balance
    accountBalance = await fundManagerInstance.balanceOf.call(accounts[1]);

    // Keep depositing until we hit the limit (if we pass the limit, fail)
    while (accountBalance.lte(defaultAccountBalanceLimitEthBN)) {
      try {
        await fundManagerInstance.deposit({ from: accounts[1], nonce: await web3.eth.getTransactionCount(accounts[1]), value: depositAmountBN });
      } catch (error) {
        assert.include(error.message, "Making this deposit would cause the balance of this account to exceed the maximum.");
        assert(accountBalance.add(depositAmountBN).gt(defaultAccountBalanceLimitEthBN));
        return;
      }
      
      accountBalance = await fundManagerInstance.balanceOf.call(accounts[1]);
    }

    assert.fail();
  });
  

  it("should make deposits until the individual account balance limit is hit", async () => {
    let fundManagerInstance = await RariFundManager.deployed();
    let fundTokenInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariEthFundToken.at(process.env.UPGRADE_FUND_TOKEN) : RariEthFundToken.deployed());

    // Get account balance in the fund and withdraw all before we start
    let accountBalance = await fundManagerInstance.balanceOf.call(accounts[1]);

    console.log("Currently have ", accountBalance.toString(10), " ETH. Withdrawing...");

    if (accountBalance.gt(web3.utils.toBN(0))) {
      await fundTokenInstance.approve(RariFundManager.address, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)), { from: accounts[1], nonce: await web3.eth.getTransactionCount(accounts[1]) });
      await fundManagerInstance.withdraw(accountBalance, { from: accounts[1], nonce: await web3.eth.getTransactionCount(accounts[1]) });
    }

    // Set default account balance limit, 1ETH
    var defaultAccountBalanceLimitUsdBN = web3.utils.toBN(1e18);
    await fundManagerInstance.setDefaultAccountBalanceLimit(defaultAccountBalanceLimitUsdBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    
    // Set individual account balance limit, 10ETH
    var individualAccountBalanceLimitUsdBN = web3.utils.toBN(10e18);
    await fundManagerInstance.setIndividualAccountBalanceLimit(accounts[1], individualAccountBalanceLimitUsdBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // deposit 1 ETH at a time
    var depositAmountBN = web3.utils.toBN(1e18);
    
    // Check account balance
    accountBalance = await fundManagerInstance.balanceOf.call(accounts[1]);
    
    // Keep depositing until we hit the limit (if we pass the limit, fail)
    while (accountBalance.lte(individualAccountBalanceLimitUsdBN)) {
      try {
        await fundManagerInstance.deposit({ from: accounts[1], value: depositAmountBN, nonce: await web3.eth.getTransactionCount(accounts[1]) });
      } catch (error) {
        assert.include(error.message, "Making this deposit would cause the balance of this account to exceed the maximum.");
        assert(accountBalance.add(depositAmountBN).gt(individualAccountBalanceLimitUsdBN));
        return;
      }
      
      accountBalance = await fundManagerInstance.balanceOf.call(accounts[1]);
    }

    assert.fail();
  });
  
  it("should make no deposits due to an individual account balance limit of 0", async () => {
    let fundManagerInstance = await RariFundManager.deployed();
    let fundTokenInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariEthFundToken.at(process.env.UPGRADE_FUND_TOKEN) : RariEthFundToken.deployed());

    // Get account balance in the fund and withdraw all before we start
    let accountBalance = await fundManagerInstance.balanceOf.call(accounts[1]);

    if (accountBalance.gt(web3.utils.toBN(0))) {
      await fundTokenInstance.approve(RariFundManager.address, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)), { from: accounts[1], nonce: await web3.eth.getTransactionCount(accounts[1]) });
      await debug(fundManagerInstance.withdraw(accountBalance, { from: accounts[1], nonce: await web3.eth.getTransactionCount(accounts[1]) }));
    }

    // Set default account balance limit
    var defaultAccountBalanceLimitEthBN = web3.utils.toBN(1e18);
    await fundManagerInstance.setDefaultAccountBalanceLimit(defaultAccountBalanceLimitEthBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    
    // To set individual account balance limit of 0, use -1 instead (0 means use default limit)
    await fundManagerInstance.setIndividualAccountBalanceLimit(accounts[1], web3.utils.toBN(-1), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // Use ETH as an example for depositing
    var depositAmountBN = web3.utils.toBN(1e17);

    // Try to deposit
    try {
      await fundManagerInstance.deposit({ from: accounts[1], nonce: await web3.eth.getTransactionCount(accounts[1]), value: depositAmountBN });
    } catch (error) {
      assert.include(error.message, "Making this deposit would cause the balance of this account to exceed the maximum.");
      return;
    }

    assert.fail();
  });
});
