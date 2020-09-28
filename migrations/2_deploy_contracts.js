require('dotenv').config();

var RariFundController = artifacts.require("./RariFundController.sol");
var RariFundManager = artifacts.require("./RariFundManager.sol");
var rETH = artifacts.require("./rETH.sol");
var RariFundProxy = artifacts.require("./RariFundProxy.sol");
var oldRariFundProxyAbi = require("./abi/RariFundProxy_v1.1.0.json");
var comptrollerAbi = require('./abi/Comptroller.json');
var erc20Abi = require('./abi/ERC20.json');

module.exports = function(deployer, network, accounts) {
  if (["live", "live-fork"].indexOf(network) >= 0) {
    if (!process.env.LIVE_GAS_PRICE) return console.error("LIVE_GAS_PRICE is missing for live deployment");
    if (!process.env.LIVE_FUND_OWNER) return console.error("LIVE_FUND_OWNER is missing for live deployment");
    if (!process.env.LIVE_FUND_REBALANCER) return console.error("LIVE_FUND_REBALANCER is missing for live deployment");
    if (!process.env.LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY) return console.error("LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY is missing for live deployment");
  }
  
  var rariFundController = null;
  var rariFundManager = null;
  var rEth = null;
  var rariFundProxy = null;

  // Normal deployment
  deployer.deploy(RariFundController).then(function() {
    return RariFundController.deployed();
  }).then(function(_rariFundController) {
    rariFundController = _rariFundController;
    return deployer.deploy(RariFundManager);
  }).then(function() {
    return RariFundManager.deployed();
  }).then(function(_rariFundManager) {
    rariFundManager = _rariFundManager;
    return rariFundController.setFundManager(RariFundManager.address);
  }).then(function() {
    return rariFundManager.setFundController(RariFundController.address);
  }).then(function() {
    return deployer.deploy(rETH);
  }).then(function() {
    return rETH.deployed();
  }).then(function(_rEth) {
    rEth = _rEth;
    return rEth.addMinter(RariFundManager.address);
  }).then(function() {
    return rEth.renounceMinter();
  }).then(function() {
    return rariFundManager.setFundToken(rETH.address);
  }).then(function() {
    return rEth.setFundManager(RariFundManager.address);
  }).then(function() {
    return deployer.deploy(RariFundProxy);
  }).then(function() {
    return rariFundManager.setFundProxy(RariFundProxy.address);
  }).then(function() {
    return RariFundProxy.deployed();
  }).then(function(_rariFundProxy) {
    rariFundProxy = _rariFundProxy;
    return rariFundProxy.setFundManager(RariFundManager.address);
  }).then(function() {
    // return rariFundProxy.setGsnTrustedSigner(process.env.LIVE_FUND_GSN_TRUSTED_SIGNER);
  }).then(function() {
    return rariFundManager.setDefaultAccountBalanceLimit(web3.utils.toBN(350e18));
  }).then(function() {
    return rariFundController.setFundRebalancer(["live", "live-fork"].indexOf(network) >= 0 ? process.env.LIVE_FUND_REBALANCER : accounts[0]);
  }).then(function() {
    return rariFundManager.setFundRebalancer(["live", "live-fork"].indexOf(network) >= 0 ? process.env.LIVE_FUND_REBALANCER : accounts[0]);
  }).then(function() {
    return rariFundManager.setInterestFeeMasterBeneficiary(["live", "live-fork"].indexOf(network) >= 0 ? process.env.LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY : accounts[0]);
  }).then(function() {
    return rariFundManager.setInterestFeeRate(web3.utils.toBN(2e17));
  }).then(function() {
    if (["live", "live-fork"].indexOf(network) >= 0) {
      // Live network: transfer ownership of deployed contracts from the deployer to the owner
      return rariFundController.transferOwnership(process.env.LIVE_FUND_OWNER).then(function() {
        return rariFundManager.transferOwnership(process.env.LIVE_FUND_OWNER);
      }).then(function() {
        return rariFundToken.transferOwnership(process.env.LIVE_FUND_OWNER);
      }).then(function() {
        return rariFundProxy.transferOwnership(process.env.LIVE_FUND_OWNER);
      });
    } else {
      // Development network: set all currencies to accepted
      // end.
    }
  });
};
