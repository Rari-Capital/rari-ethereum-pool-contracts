/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

const { deployProxy, admin } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

var DydxPoolController = artifacts.require("./lib/pools/DydxPoolController.sol");
var CompoundPoolController = artifacts.require("./lib/pools/CompoundPoolController.sol");
var AavePoolController = artifacts.require("./lib/pools/AavePoolController.sol");
var KeeperDaoPoolController = artifacts.require("./lib/pools/KeeperDaoPoolController.sol");
var ZeroExExchangeController = artifacts.require("./lib/exchanges/ZeroExExchangeController.sol");
var RariFundController = artifacts.require("./RariFundController.sol");
var RariFundManager = artifacts.require("./RariFundManager.sol");
var RariFundToken = artifacts.require("./RariFundToken.sol");
var RariFundProxy = artifacts.require("./RariFundProxy.sol");

module.exports = async function(deployer, network, accounts) {
  if (["live", "live-fork"].indexOf(network) >= 0) {
    if (!process.env.LIVE_GAS_PRICE) return console.error("LIVE_GAS_PRICE is missing for live deployment");
    if (!process.env.LIVE_FUND_OWNER) return console.error("LIVE_FUND_OWNER is missing for live deployment");
    if (!process.env.LIVE_FUND_REBALANCER) return console.error("LIVE_FUND_REBALANCER is missing for live deployment");
    if (!process.env.LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY) return console.error("LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY is missing for live deployment");
  }

  // Normal deployment!
  // Deploy liquidity pool and currency exchange libraries
  await deployer.deploy(DydxPoolController);
  await deployer.deploy(CompoundPoolController);
  await deployer.deploy(KeeperDaoPoolController);
  await deployer.deploy(AavePoolController);
  await deployer.deploy(ZeroExExchangeController);

  // Link libraries to RariFundController
  await deployer.link(DydxPoolController, RariFundController);
  await deployer.link(CompoundPoolController, RariFundController);
  await deployer.link(AavePoolController, RariFundController);
  await deployer.link(KeeperDaoPoolController, RariFundController);
  await deployer.link(ZeroExExchangeController, RariFundController);

  // Deploy RariFundController and RariFundManager
  var rariFundController = await deployer.deploy(RariFundController);
  var rariFundManager = await deployProxy(RariFundManager, [], { deployer, unsafeAllowCustomTypes: true });

  // Connect RariFundController and RariFundManager
  await rariFundController.setFundManager(RariFundManager.address);
  await rariFundManager.setFundController(RariFundController.address);

  // Set Aave referral code
  await rariFundController.setAaveReferralCode(86);
  
  // Deploy RariFundToken
  var rariFundToken = await deployProxy(RariFundToken, [], { deployer });
  
  // Add RariFundManager as as RariFundToken minter
  await rariFundToken.addMinter(RariFundManager.address);

  // Connect RariFundToken to RariFundManager
  await rariFundManager.setFundToken(RariFundToken.address);

  // Set fund rebalancer on controller and manager
  await rariFundController.setFundRebalancer(["live", "live-fork"].indexOf(network) >= 0 ? process.env.LIVE_FUND_REBALANCER : process.env.DEVELOPMENT_ADDRESS);
  await rariFundManager.setFundRebalancer(["live", "live-fork"].indexOf(network) >= 0 ? process.env.LIVE_FUND_REBALANCER : process.env.DEVELOPMENT_ADDRESS);

  // Set interest fee master beneficiary
  await rariFundManager.setInterestFeeMasterBeneficiary(["live", "live-fork"].indexOf(network) >= 0 ? process.env.LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY : process.env.DEVELOPMENT_ADDRESS);

  // Set interest fee rate to 9.5%
  await rariFundManager.setInterestFeeRate(web3.utils.toBN(0.095e18));

  // Link libraries to RariFundProxy
  await deployer.link(ZeroExExchangeController, RariFundProxy);

  // Deploy RariFundProxy
  var rariFundProxy = await deployer.deploy(RariFundProxy);

  // Connect RariFundManager and RariFundProxy
  await rariFundManager.setFundProxy(RariFundProxy.address);
  await rariFundProxy.setFundManager(RariFundManager.address);

  if (["live", "live-fork"].indexOf(network) >= 0) {
    // Live network: transfer ownership of deployed contracts from the deployer to the owner
    await rariFundController.transferOwnership(process.env.LIVE_FUND_OWNER);
    await rariFundManager.transferOwnership(process.env.LIVE_FUND_OWNER);
    await rariFundToken.addMinter(process.env.LIVE_FUND_OWNER);
    await rariFundToken.renounceMinter();
    await rariFundToken.addPauser(process.env.LIVE_FUND_OWNER);
    await rariFundToken.renouncePauser();
    await rariFundProxy.transferOwnership(process.env.LIVE_FUND_OWNER);
    await admin.transferProxyAdminOwnership(process.env.LIVE_FUND_OWNER);
  }
};