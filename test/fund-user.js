const erc20Abi = require('./abi/ERC20.json');
const cErc20DelegatorAbi = require('./abi/CErc20Delegator.json');

const currencies = require('./fixtures/currencies.json');
const pools = require('./fixtures/pools.json');

const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");
const RariEthFundToken = artifacts.require("RariFundToken");

async function forceAccrueCompound(currencyCode, account) {
  var cErc20Contract = new web3.eth.Contract(cErc20DelegatorAbi, pools["Compound"].currencies[currencyCode].cTokenAddress);
  
  try {
    await cErc20Contract.methods.accrueInterest().send({ from: account, nonce: await web3.eth.getTransactionCount(account) });
  } catch (error) {
    try {
      await cErc20Contract.methods.accrueInterest().send({ from: account, nonce: await web3.eth.getTransactionCount(account) });
    } catch (error) {
      console.error("Both attempts to force accrue interest on Compound " + currencyCode + " failed. Not trying again!");
    }
  }
}

// These tests expect the owner and the fund rebalancer of RariFundManager to be set to accounts[0]
contract("RariFundManager, RariFundController", accounts => {
  it("should make a deposit, deposit to pools, accrue interest, and make a withdrawal", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await RariFundManager.deployed();
    let fundTokenInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariEthFundToken.at(process.env.UPGRADE_FUND_TOKEN) : RariEthFundToken.deployed());

    // Use Compound as an example
    // for (const currencyCode of Object.keys(pools["Compound"].currencies)) {
    var amountBN = web3.utils.toBN(10 ** 18);
    // var amountUsdBN = 18 >= currencies[currencyCode].decimals ? amountBN.mul(web3.utils.toBN(10 ** (18 - currencies[currencyCode].decimals))) : amountBN.div(web3.utils.toBN(10 ** (currencies[currencyCode].decimals - 18)));
    
    // Check balances
    let initialAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    let initialFundBalance = await fundManagerInstance.getFundBalance.call();
    let initialrETHBalance = await fundTokenInstance.balanceOf.call(accounts[0]);
    
    // Approve tokens to RariFundManager
    // var erc20Contract = new web3.eth.Contract(erc20Abi, currencies[currencyCode].tokenAddress);
    // await erc20Contract.methods.approve(RariFundManager.address, amountBN.toString()).send({ from: accounts[0] });

    // RariFundManager.deposit
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });

    // Check balances and interest
    let postDepositAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    assert(postDepositAccountBalance.gte(initialAccountBalance.add(amountBN).mul(web3.utils.toBN(999999)).div(web3.utils.toBN(1000000))));
    let postDepositFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(postDepositFundBalance.gte(initialFundBalance.add(amountBN).mul(web3.utils.toBN(999999)).div(web3.utils.toBN(1000000))));
    let postDepositrETHBalance = await fundTokenInstance.balanceOf.call(accounts[0]);
    assert(postDepositrETHBalance.gt(initialrETHBalance));
    let postDepositInterestAccrued = await fundManagerInstance.getInterestAccrued.call();

    // Deposit to pool (using Compound as an example)
    // TODO: Ideally, deposit to pool via rari-fund-rebalancer
    await fundControllerInstance.approveToPool(1, amountBN, { from: accounts[0] });
    await fundControllerInstance.depositToPool(1, amountBN, { from: accounts[0] });

    // Force accrue interest
    await forceAccrueCompound(currencyCode, accounts[0]);

    // Check balances and interest after waiting for interest
    let preWithdrawalAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    assert(preWithdrawalAccountBalance.gt(postDepositAccountBalance));
    let preWithdrawalFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(preWithdrawalFundBalance.gt(postDepositFundBalance));
    let preWithdrawalRftBalance = await fundTokenInstance.balanceOf.call(accounts[0]);
    assert(preWithdrawalRftBalance.eq(postDepositrETHBalance));
    let preWithdrawalInterestAccrued = await fundManagerInstance.getInterestAccrued.call();
    assert(preWithdrawalInterestAccrued.gt(postDepositInterestAccrued));

    // RariFundManager.withdraw
    await fundTokenInstance.approve(RariFundManager.address, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    await fundManagerInstance.withdraw(amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // TODO: Check balances and assert with post-interest balances
    let finalAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    assert(finalAccountBalance.lt(preWithdrawalAccountBalance));
    let finalFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(finalFundBalance.lt(preWithdrawalFundBalance));
    let finalRftBalance = await fundTokenInstance.balanceOf.call(accounts[0]);
    assert(finalRftBalance.lt(preWithdrawalRftBalance));
    });
    

});
