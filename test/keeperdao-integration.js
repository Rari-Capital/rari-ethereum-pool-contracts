/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

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

    let preDepositBalance = web3.utils.toBN(await web3.eth.getBalance(accounts[0]));
    await fundControllerInstance.approvekEtherToKeeperDaoPool(web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)));

    var amountBN = web3.utils.toBN(1e18);
        
    // Check balances
    let initialFundBalance = await fundManagerInstance.getFundBalance.call();
    
    // Deposit to KeeperDAO
    await fundManagerInstance.deposit({ from: accounts[0], value: amountBN });
    await fundControllerInstance.depositToPool(2, amountBN, { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    // Check balances and interest
    let postDepositFundBalance = await fundManagerInstance.getFundBalance.call();

    assert(postDepositFundBalance.gte(initialFundBalance.add(amountBN).mul(web3.utils.toBN(999999)).div(web3.utils.toBN(1000000))));

    await fundTokenInstance.approve(RariFundManager.address, web3.utils.toBN(2).pow(web3.utils.toBN(256)).sub(web3.utils.toBN(1)), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });
    await fundManagerInstance.withdraw(amountBN.muln(9999).divn(10000), { from: accounts[0], nonce: await web3.eth.getTransactionCount(accounts[0]) });

    let postWithdrawalFundBalance = await fundManagerInstance.getFundBalance.call();
    assert(postWithdrawalFundBalance.lt(postDepositFundBalance));
    let finalBalance = web3.utils.toBN(await web3.eth.getBalance(accounts[0]));
    assert(finalBalance.gte(preDepositBalance.mul(web3.utils.toBN(99999)).div(web3.utils.toBN(100000))));

  });
});
