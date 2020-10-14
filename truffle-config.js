const HDWalletProvider = require("@truffle/hdwallet-provider");
require('dotenv').config();

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  networks: {
    development: {
      provider: function() {
        var keys = [process.env.DEVELOPMENT_PRIVATE_KEY];
        if (process.env.DEVELOPMENT_PRIVATE_KEY_SECONDARY) keys.push(process.env.DEVELOPMENT_PRIVATE_KEY_SECONDARY);
        if (process.env.UPGRADE_FUND_OWNER_PRIVATE_KEY) keys.push(process.env.UPGRADE_FUND_OWNER_PRIVATE_KEY);
        return new HDWalletProvider(keys, "http://localhost:8546"); // Fork mainnet geth instance with ganache-core
      },
      network_id: 1,
      gasPrice: 1e8,
      from: process.env.DEVELOPMENT_ADDRESS
    },
    live: {
      provider: function() {
        var keys = [process.env.LIVE_DEPLOYER_PRIVATE_KEY];
        if (process.env.UPGRADE_FUND_OWNER_PRIVATE_KEY) keys.push(process.env.UPGRADE_FUND_OWNER_PRIVATE_KEY);
        return new HDWalletProvider(keys, process.env.LIVE_WEB3_PROVIDER_URL);
      },
      network_id: 1,
      gasPrice: parseInt(process.env.LIVE_GAS_PRICE),
      from: process.env.LIVE_DEPLOYER_ADDRESS
    }
  },
  compilers: {
    solc: {
      version: "0.5.17",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};
