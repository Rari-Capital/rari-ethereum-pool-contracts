// SPDX-License-Identifier: UNLICENSED
const { deployProxy, upgradeProxy, admin } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

var DydxPoolController = artifacts.require("./lib/pools/DydxPoolController.sol");
var CompoundPoolController = artifacts.require("./lib/pools/CompoundPoolController.sol");
var KeeperDaoPoolController = artifacts.require("./lib/pools/KeeperDaoPoolController.sol");
var AavePoolController = artifacts.require("./lib/pools/AavePoolController.sol");
var AlphaPoolController = artifacts.require("./lib/pools/AlphaPoolController.sol");
var EnzymePoolController = artifacts.require("./lib/pools/EnzymePoolController.sol");
var ZeroExExchangeController = artifacts.require("./lib/exchanges/ZeroExExchangeController.sol");
var RariFundController = artifacts.require("./RariFundController.sol");
var RariFundManager = artifacts.require("./RariFundManager.sol");
var RariFundToken = artifacts.require("./RariFundToken.sol");
var RariFundProxy = artifacts.require("./RariFundProxy.sol");

module.exports = async function(deployer, network, accounts) {
  if (["live", "live-fork"].indexOf(network) >= 0) {
    if (!process.env.ENZYME_COMPTROLLER) return console.error("ENZYME_COMPTROLLER is missing for live deployment");
    if (!process.env.LIVE_GAS_PRICE) return console.error("LIVE_GAS_PRICE is missing for live deployment");
    if (!process.env.LIVE_FUND_OWNER) return console.error("LIVE_FUND_OWNER is missing for live deployment");
    if (!process.env.LIVE_FUND_REBALANCER) return console.error("LIVE_FUND_REBALANCER is missing for live deployment");
    if (!process.env.LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY) return console.error("LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY is missing for live deployment");
  }
  
  if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) {
    if (!process.env.UPGRADE_OLD_FUND_CONTROLLER_ADDRESS) return console.error("UPGRADE_OLD_FUND_CONTROLLER_ADDRESS is missing for upgrade");
    if (!process.env.UPGRADE_FUND_MANAGER_ADDRESS) return console.error("UPGRADE_FUND_MANAGER_ADDRESS is missing for upgrade");
    if (!process.env.UPGRADE_FUND_OWNER_ADDRESS) return console.error("UPGRADE_FUND_OWNER_ADDRESS is missing for upgrade");
    
    if (["live", "live-fork"].indexOf(network) >= 0) {
      if (!process.env.LIVE_UPGRADE_FUND_OWNER_PRIVATE_KEY) return console.error("LIVE_UPGRADE_FUND_OWNER_PRIVATE_KEY is missing for live upgrade");
      if (!process.env.LIVE_UPGRADE_TIMESTAMP_COMP_CLAIMED_AND_EXCHANGED || process.env.LIVE_UPGRADE_TIMESTAMP_COMP_CLAIMED_AND_EXCHANGED < ((new Date()).getTime() / 1000) - 3600 || process.env.LIVE_UPGRADE_TIMESTAMP_COMP_CLAIMED_AND_EXCHANGED > (new Date()).getTime() / 1000) return console.error("LIVE_UPGRADE_TIMESTAMP_COMP_CLAIMED_AND_EXCHANGED is missing, invalid, or out of date for live upgrade");
    } else {
      if (!process.env.UPGRADE_FUND_TOKEN_ADDRESS) return console.error("UPGRADE_FUND_TOKEN_ADDRESS is missing for development upgrade");
      if (!process.env.UPGRADE_FUND_PROXY_ADDRESS) return console.error("UPGRADE_FUND_PROXY_ADDRESS is missing for development upgrade");
    }

    // Upgrade from v1.1.0 (RariFundManager v1.1.0) to v1.2.0
    RariFundManager.class_defaults.from = process.env.UPGRADE_FUND_OWNER_ADDRESS;
    var rariFundManager = await upgradeProxy(process.env.UPGRADE_FUND_MANAGER_ADDRESS, RariFundManager, { deployer });

    // Add missing pools
    await rariFundManager.addMissingPools();

    // Upgrade from v1.1.0 (RariFundController v1.0.0) to v1.2.0
    var oldRariFundController = new web3.eth.Contract(RariFundController.abi, process.env.UPGRADE_OLD_FUND_CONTROLLER_ADDRESS);

    // Deploy liquidity pool and currency exchange libraries
    await deployer.deploy(DydxPoolController);
    await deployer.deploy(CompoundPoolController);
    await deployer.deploy(KeeperDaoPoolController);
    await deployer.deploy(AavePoolController);
    await deployer.deploy(AlphaPoolController);
    await deployer.deploy(EnzymePoolController);
    await deployer.deploy(ZeroExExchangeController);

    // Link libraries to RariFundController
    await deployer.link(DydxPoolController, RariFundController);
    await deployer.link(CompoundPoolController, RariFundController);
    await deployer.link(KeeperDaoPoolController, RariFundController);
    await deployer.link(AavePoolController, RariFundController);
    await deployer.link(AlphaPoolController, RariFundController);
    await deployer.link(EnzymePoolController, RariFundController);
    await deployer.link(ZeroExExchangeController, RariFundController);

    // Deploy new RariFundController
    var rariFundController = await deployer.deploy(RariFundController);

    // Set Enzyme comptroller if applicable
    if (process.env.ENZYME_COMPTROLLER) await rariFundController.setEnzymeComptroller(process.env.ENZYME_COMPTROLLER);

    // Disable the fund on the old RariFundController
    var options = { from: process.env.UPGRADE_FUND_OWNER_ADDRESS };
    if (["live", "live-fork"].indexOf(network) >= 0) {
      options.gas = 1e6;
      options.gasPrice = parseInt(process.env.LIVE_GAS_PRICE);
    }
    await oldRariFundController.methods.disableFund().send(options);

    // Disable the fund on the RariFundManager
    await rariFundManager.disableFund();

    // Upgrade RariFundController
    var options = { from: process.env.UPGRADE_FUND_OWNER_ADDRESS, gas: 5e6 };
    if (["live", "live-fork"].indexOf(network) >= 0) options.gasPrice = parseInt(process.env.LIVE_GAS_PRICE);
    await oldRariFundController.methods.upgradeFundController(RariFundController.address).send(options);

    // Connect new RariFundController and RariFundManager
    await rariFundController.setFundManager(RariFundManager.address);
    await rariFundManager.setFundController(RariFundController.address);

    // Re-enable the fund on the RariFundManager
    await rariFundManager.enableFund();

    // Set Aave referral code
    await rariFundController.setAaveReferralCode(86);

    // Set fund rebalancer on controller and manager
    await rariFundController.setFundRebalancer(["live", "live-fork"].indexOf(network) >= 0 ? process.env.LIVE_FUND_REBALANCER : process.env.DEVELOPMENT_ADDRESS);

    if (["live", "live-fork"].indexOf(network) >= 0) {
      // Live network: transfer ownership of deployed contracts from the deployer to the owner
      await rariFundController.transferOwnership(process.env.LIVE_FUND_OWNER);
    } else {
      // Development network: transfer ownership of contracts to development address and set development address as rebalancer
      await rariFundManager.transferOwnership(process.env.DEVELOPMENT_ADDRESS, { from: process.env.UPGRADE_FUND_OWNER_ADDRESS });
      var rariFundProxy = await RariFundProxy.at(process.env.UPGRADE_FUND_PROXY_ADDRESS);
      await rariFundProxy.transferOwnership(process.env.DEVELOPMENT_ADDRESS, { from: process.env.UPGRADE_FUND_OWNER_ADDRESS });
      // TODO: await admin.transferProxyAdminOwnership(process.env.DEVELOPMENT_ADDRESS, { from: process.env.UPGRADE_FUND_OWNER_ADDRESS });
      RariFundManager.class_defaults.from = process.env.DEVELOPMENT_ADDRESS;
      await rariFundManager.setFundRebalancer(process.env.DEVELOPMENT_ADDRESS);
    }
  } else {
    // Normal deployment!
    // Deploy liquidity pool and currency exchange libraries
    await deployer.deploy(DydxPoolController);
    await deployer.deploy(CompoundPoolController);
    await deployer.deploy(KeeperDaoPoolController);
    await deployer.deploy(AavePoolController);
    await deployer.deploy(AlphaPoolController);
    await deployer.deploy(EnzymePoolController);
    await deployer.deploy(ZeroExExchangeController);

    // Link libraries to RariFundController
    await deployer.link(DydxPoolController, RariFundController);
    await deployer.link(CompoundPoolController, RariFundController);
    await deployer.link(KeeperDaoPoolController, RariFundController);
    await deployer.link(AavePoolController, RariFundController);
    await deployer.link(AlphaPoolController, RariFundController);
    await deployer.link(EnzymePoolController, RariFundController);
    await deployer.link(ZeroExExchangeController, RariFundController);

    // Deploy RariFundController and RariFundManager
    var rariFundController = await deployer.deploy(RariFundController);
    var rariFundManager = await deployProxy(RariFundManager, [], { deployer });

    // Set Enzyme comptroller if applicable
    if (process.env.ENZYME_COMPTROLLER) await rariFundController.setEnzymeComptroller(process.env.ENZYME_COMPTROLLER);

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
  }
};