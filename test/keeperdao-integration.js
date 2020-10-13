const erc20Abi = require('./abi/ERC20.json');
const cErc20DelegatorAbi = require('./abi/CErc20Delegator.json');

const pools = require('./fixtures/pools.json');

const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");
const RariEthFundToken = artifacts.require("RariFundToken");


// These tests expect the owner and the fund rebalancer of RariFundManager to be set to accounts[0]
contract("RariFundManager, RariFundController", accounts => {
  it("should make a deposit to keeperdao, then withdraw all", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await RariFundManager.deployed();
    let fundTokenInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariEthFundToken.at(process.env.UPGRADE_FUND_TOKEN) : RariEthFundToken.deployed());

    var amountBN = web3.utils.toBN(1e18);
        
    // Check balances
    // let initialAccountBalance = await fundManagerInstance.balanceOf.call(accounts[0]);
    let initialFundBalance = await fundManagerInstance.getFundBalance.call();
    
    console.log("Pre deposit balance: ", initialFundBalance.toString());
    // RariFundManager.deposit
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });
    await fundControllerInstance.depositToPool(2, amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // Check balances and interest
    let postDepositFundBalance = await fundManagerInstance.getFundBalance.call();

    console.log("Post deposit balance: ", postDepositFundBalance.toString(10));

    assert(postDepositFundBalance.gte(initialFundBalance.add(amountBN).mul(web3.utils.toBN(999999)).div(web3.utils.toBN(1000000))));

    let postDepositInterestAccrued = await fundManagerInstance.getInterestAccrued.call();

    // Check balances and interest after waiting for interest
    let preWithdrawalFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(preWithdrawalFundBalance.gt(postDepositFundBalance));

    let preWithdrawalInterestAccrued = await fundManagerInstance.getInterestAccrued.call();
    assert(preWithdrawalInterestAccrued.gt(postDepositInterestAccrued));

    // RariFundManager.withdraw
    await fundControllerInstance.withdrawFromPool(2, amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // TODO: Check balances and assert with post-interest balances
    let finalFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(finalFundBalance.lt(preWithdrawalFundBalance));
    });
    

});
