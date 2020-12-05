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

If you are upgrading from `v1.1.0`, set `UPGRADE_FROM_LAST_VERSION=1` to enable upgrading and configure the following:

    UPGRADE_OLD_FUND_CONTROLLER_ADDRESS=0xD9F223A36C2e398B0886F945a7e556B41EF91A3C
    UPGRADE_FUND_MANAGER_ADDRESS=0xD6e194aF3d9674b62D1b30Ec676030C23961275e
    UPGRADE_FUND_OWNER_ADDRESS=0x10dB6Bce3F2AE1589ec91A872213DAE59697967a

Then, copy the OpenZeppelin artifacts for the official deployed `v1.1.0` contracts from `.openzeppelin/mainnet.json` to `.openzeppelin/unknown-1337.json`. If you decide to disable upgrading by setting restoring `UPGRADE_FROM_LAST_VERSION=0`, make sure to delete `.openzeppelin/unknown-1337.json`.

To test the contracts, first fork the Ethereum mainnet. Begin by configuring `DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED` in `.env` (set to any mainnet Web3 HTTP provider JSON-RPC URL; we use a local `geth` instance, specifically a light client started with `geth --syncmode light --rpc --rpcapi eth,web3,debug,net`; Infura works too, but beware of latency and rate limiting). To start the fork, run `npm run ganache`. *If you would like to change the port, make sure to configure `scripts/ganache.js`, `scripts/test.sh`, and the `development` network in `truffle-config.js`.* Note that you will likely have to regularly restart your fork, especially when forking from a node without archive data or when using live 0x API responses to make currency exchanges.

To deploy the contracts to your private mainnet fork: `truffle migrate --network development --skip-dry-run --reset`

To run automated tests on the contracts on your private mainnet fork, run `npm test` (which runs `npm run ganache` in the background for you). If you are upgrading from `v1.1.0`, you must also set the following variables in `.env`:

    UPGRADE_FUND_TOKEN_ADDRESS=0xCda4770d65B4211364Cb870aD6bE19E7Ef1D65f4
    UPGRADE_FUND_PROXY_ADDRESS=0xa3cc9e4B9784c80a05B3Af215C32ff223C3ebE5c

## Live deployment

In `.env`, configure `LIVE_DEPLOYER_ADDRESS`, `LIVE_DEPLOYER_PRIVATE_KEY`, `LIVE_WEB3_PROVIDER_URL`, `LIVE_GAS_PRICE` (ideally, use the "fast" price listed by [ETH Gas Station](https://www.ethgasstation.info/)), `LIVE_FUND_OWNER`, `LIVE_FUND_REBALANCER`, and `LIVE_FUND_INTEREST_FEE_MASTER_BENEFICIARY` to deploy to the mainnet.

If you are upgrading from `v1.1.0`, set `UPGRADE_FROM_LAST_VERSION=1` to enable upgrading and configure the following:

    UPGRADE_OLD_FUND_CONTROLLER_ADDRESS=0xD9F223A36C2e398B0886F945a7e556B41EF91A3C
    UPGRADE_FUND_MANAGER_ADDRESS=0xD6e194aF3d9674b62D1b30Ec676030C23961275e
    UPGRADE_FUND_OWNER_ADDRESS=0x10dB6Bce3F2AE1589ec91A872213DAE59697967a

You must also set `LIVE_UPGRADE_FUND_OWNER_PRIVATE_KEY`.

Then, migrate: `truffle migrate --network live`

## Credits

Rari Capital's smart contracts are developed by [David Lucid](https://github.com/davidlucid) of David Lucid LLC.
