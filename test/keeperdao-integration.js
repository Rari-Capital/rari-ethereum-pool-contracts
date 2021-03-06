// SPDX-License-Identifier: UNLICENSED
const RariFundController = artifacts.require("RariFundController");
const RariFundManager = artifacts.require("RariFundManager");
const RariFundToken = artifacts.require("RariFundToken");

if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) {
  RariFundManager.address = process.env.UPGRADE_FUND_MANAGER_ADDRESS;
  RariFundToken.address = process.env.UPGRADE_FUND_TOKEN_ADDRESS;
}

// These tests expect the owner and the fund rebalancer of RariFundManager to be set to accounts[0]
contract("RariFundManager, RariFundController", accounts => {
  it("should make a deposit to keeperdao, then withdraw all", async () => {
    let fundControllerInstance = await RariFundController.deployed();
    let fundManagerInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundManager.at(process.env.UPGRADE_FUND_MANAGER_ADDRESS) : RariFundManager.deployed());
    let fundTokenInstance = await (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0 ? RariFundToken.at(process.env.UPGRADE_FUND_TOKEN_ADDRESS) : RariFundToken.deployed());

    let preDepositAccountBalance = web3.utils.toBN(await web3.eth.getBalance(accounts[0]));
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    var amountBN = web3.utils.toBN(1e18);

    // Check balances
    let initialFundBalance = await fundManagerInstance.getFundBalance.call();
    
    // Deposit to KeeperDAO
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });
    await fundControllerInstance.depositToPool(2, amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // Calculate deposit fee, subtract it, and check balances
    let postDepositFundBalance = await fundManagerInstance.getFundBalance.call();
    let depositFeeBN = amountBN.muln(64).divn(10000);
    let amountAfterFeeBN = amountBN.sub(depositFeeBN);
    assert(postDepositFundBalance.gte(initialFundBalance.add(amountAfterFeeBN.mul(web3.utils.toBN(999999)).div(web3.utils.toBN(1000000)))));

    // Withdraw from KeeperDAO
    await fundTokenInstance.approve(RariFundManager.address, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    await fundManagerInstance.withdraw(amountAfterFeeBN.mul(web3.utils.toBN(999999)).div(web3.utils.toBN(1000000)), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // Check balances again
    let postWithdrawalFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(postWithdrawalFundBalance.lt(postDepositFundBalance));
    let finalAccountBalance = web3.utils.toBN(await web3.eth.getBalance(accounts[0]));
    assert(finalAccountBalance.gte(preDepositAccountBalance.mul(web3.utils.toBN(9999)).div(web3.utils.toBN(10000))));
  });
});
