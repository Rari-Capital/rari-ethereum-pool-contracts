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

    let preDepositBalance = await web3.eth.getBalance(accounts[0]);
    
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    var amountBN = web3.utils.toBN(1e18);
        
    // Check balances
    let initialFundBalance = await fundManagerInstance.getFundBalance.call();
    
    console.log("Pre deposit balance: ", initialFundBalance.toString());

    // RariFundManager.deposit
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });
    await fundControllerInstance.depositToPool(2, amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // Check balances and interest
    let postDepositFundBalance = await fundManagerInstance.getFundBalance.call();

    console.log("Post deposit balance: ", postDepositFundBalance.toString(10));

    assert(postDepositFundBalance.gte(initialFundBalance.add(amountBN).mul(web3.utils.toBN(999999)).div(web3.utils.toBN(1000000))));

    // RariFundManager.withdraw
    await fundManagerInstance.withdraw(amountBN.muln(9999).divn(10000), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // TODO: Check balances and assert with post-interest balances
    let finalFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(finalFundBalance.lt(preWithdrawalFundBalance));

    let finalBalance = await web3.eth.getBalance(accounts[0]);

    console.log("Initial balance: ", preDepositBalance.toString(10));
    console.log("Final balance: ", finalBalance.toString(10));

    assert(finalBalance.gte(preDepositBalance.mul(web3.utils.toBN(999999)).div(web3.utils.toBN(1000000))));

    });
    

});
