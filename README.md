# Rari Ethereum Pool: Smart Contracts

Welcome to `rari-ethereum-pool-contracts`, the central repository for the Solidity source code behind the Rari Ethereum Pool's Ethereum-based smart contracts (with automated tests and documentation).

## How it works

The Rari Ethereum Pool is a decentralized and fully-audited stablecoin lending aggregator optimized for yield based on the Ethereum blockchain. Find out more about Rari Capital at [rari.capital](https://rari.capital).

## Installation (for development and deployment)

We, as well as others, had success using Truffle on Node.js `v12.18.2` with the latest version of NPM.

To install the latest version of Truffle: `npm install -g truffle`

*Though the latest version of Truffle should work, to compile, deploy, and test our contracts, we used Truffle `v5.1.45` (which should use `solc` version `0.5.17+commit.d19bba13.Emscripten.clang` and Web3.js `v1.2.1`).*

To install all our dependencies: `npm install`

## Compiling the contracts

`npm run compile`

## Testing the contracts

To test the contracts, first fork the Ethereum mainnet. Begin by configuring `DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED` in `.env` (set to any mainnet Web3 HTTP provider JSON-RPC URL; we use a local `geth` instance, specifically a light client started with `geth --syncmode light --rpc --rpcapi eth,web3,debug,net`; Infura works too, but beware of latency and rate limiting). To start the fork, run `npm run ganache`. *If you would like to change the port, make sure to configure `scripts/ganache.js`, `scripts/test.sh`, and the `development` network in `truffle-config.js`.* Note that you will likely have to regularly restart your fork, especially when forking from a node without archive data or when using live 0x API responses to make currency exchanges.

To deploy the contracts to your private mainnet fork: `truffle migrate --network development --skip-dry-run --reset`

To run automated tests on the contracts on your private mainnet fork, run `npm test` (which runs `npm run ganache` in the background for you).

If you'd like to test gasless deposits via `RariFundProxy.deposit` via the Gas Station Network:

* Download `https://github.com/OpenZeppelin/openzeppelin-gsn-provider/blob/master/bin/gsn-relay` to `bin/gsn-relay` and set permissions with `chmod +x bin/gsn-relay`.
* Making sure `npx` is installed, run `npm dev-gsn`.
* Fund `RariFundProxy` using `npx @openzeppelin/gsn-helpers fund-recipient --recipient $RARI_FUND_PROXY_ADDRESS -n http://localhost:8546 -f $FROM_ADDRESS` or [this tool](https://www.opengsn.org/recipients) (or manually send ETH to `RelayHub(0xD216153c06E857cD7f72665E0aF1d7D82172F494).depositFor(address target)`).
* Run `rari-gsn-signer` with `pm2 start ecosystem.config.js` after configuring `ecosystem.config.js`.
* *Please note that as of now, the web client and the GSN signer are configured so that gas is paid only for deposits of least 250 DAI/USDC/USDT by first-time users.*

## Live deployment

In `.env`, configure `LIVE_DEPLOYER_ADDRESS`, `LIVE_DEPLOYER_PRIVATE_KEY`, `LIVE_WEB3_PROVIDER_URL`, `LIVE_GAS_PRICE` (ideally, use the "fast" price listed by [ETH Gas Station](https://www.ethgasstation.info/)), `LIVE_FUND_OWNER`, `LIVE_FUND_REBALANCER`, `LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY`, and `LIVE_FUND_GSN_TRUSTED_SIGNER` to deploy to the mainnet.

Then, migrate: `truffle migrate --network live`

If you'd like to provide gasless deposits via `RariFundProxy.deposit` via the Gas Station Network:

* Fund `RariFundProxy` using `npx @openzeppelin/gsn-helpers fund-recipient --recipient $RARI_FUND_PROXY_ADDRESS -n $ETHEREUM_NODE_URL -f $FROM_ADDRESS` or [this tool](https://www.opengsn.org/recipients) (or manually send ETH to `RelayHub(0xD216153c06E857cD7f72665E0aF1d7D82172F494).depositFor(address target)`).
* Run `rari-gsn-signer` with `pm2 start ecosystem.config.js --env production` after configuring `ecosystem.config.js`.
* *Please note that as of now, the web client and the GSN signer are configured so that gas is paid only for deposits of least 250 DAI/USDC/USDT by first-time users.*

## Credits

Rari Capital's smart contracts are developed by [David Lucid](https://github.com/davidlucid) of David Lucid LLC.
