# Rari Ethereum Pool: How it Works

This document explains how the Rari Ethereum Pool works under the hood. This content is also available [on our website](https://rari.capital/current.html).

## Generating Yield

Currently, the Rari Ethereum Pool generates yield by depositing Ethereum (ETH) into a combination of the following lending protocols:

* [dYdX](https://dydx.exchange/)
* [Compound](https://compound.finance/)
* [Aave](https://aave.com/)
* [KeeperDAO](https://keeperdao.com/)

Rari optimizes yield by allocating assets to the pools with the highest interest rates. In the near future, we will be generating yield through additional lending protocols, among other strategies.

## REPT (Rari Ethereum Pool Token)

Each user's share of the Rari Ethereum Pool is represented by their REPT (Rari Ethereum Pool Token) balance. When you deposit funds to the Ethereum Pool, an equivalent amount of REPT is minted to your account. When you withdraw funds from the Ethereum Pool, the equivalent amount of REPT is burned from your account. As soon as you deposit, you start earning yield. Essentially, Rari Ethereum Pool holdings and yield are split up across REPT holders proportionally to their balances.

## Deposits

Only Ethereum (ETH) is accepted for direct deposits (direct meaning without exchange to ETH). To deposit another currency, you must exchange your funds before depositing. Fortunately, Rari can exchange and deposit your funds in the same transaction via [0x](https://0x.org/) (please be aware that exchanges via 0x are subject to slippage due to price spread as well as an ETH protocol fee).

See [`USAGE.md`](USAGE.md) for more information on how to deposit via the smart contracts and [`API.md`](API.md) for a detailed reference on the smart contract methods involved. See the Rari SDK for easy implementation and the web client for easy usage.

## Withdrawals

Only Ethereum (ETH) is available for direct withdrawals. To withdraw another currency, you must exchange your funds after withdrawing. Fortunately, Rari can withdraw and exchange your funds in the same transaction via [0x](https://0x.org/) (please be aware that exchanges via 0x are subject to slippage due to price spread as well as an ETH protocol fee).

See [`USAGE.md`](USAGE.md) for more information on how to withdraw via the smart contracts and [`API.md`](API.md) for a detailed reference on the smart contract methods involved. See the Rari SDK for easy implementation and the web client for easy usage.

## Structure

The Rari Ethereum Pool is composed of 5 user-facing **smart contracts** in total (see [`DEPLOYED.md`](DEPLOYED.md) for deployed addresses):

* `RariFundManager` is the Rari Ethereum Pool's main contract, handling deposits, withdrawals, ETH balances, interest, fees, etc.
* `RariFundController` holds supplied funds and is used by the rebalancer to deposit and withdraw from pools and liquidate COMP rewards into ETH.
* `RariFundToken` is the contract behind the Rari Ethereum Pool Token (REPT), an ERC20 token used to internally account for the ownership of funds supplied to the Rari Ethereum Pool.
* `RariFundProxy` includes wrapper functions built on top of `RariFundManager`: exchange and deposit and withdraw and exchange.

A centralized (but soon to be decentralized) **rebalancer** controls which pools hold which currencies at any given time but only has permission to move funds between pools and liquidate COMP rewards, not withdraw funds elsewhere.

## Security

Rari's Ethereum-based smart contracts are written in Solidity and audited by [Quantstamp](https://quantstamp.com/) (as well as various other partners) for security. Rari does not have control over your funds: instead, the Ethereum blockchain executes all secure code across its entire decentralized network (making it very difficult and extremely costly to rewrite history), and your funds are only withdrawable by you.

While the centralized (but soon to be decentralized) rebalancer does have control over which pools hold which currencies at any given time but only has permission to move funds between pools and liquidate COMP rewards, not withdraw funds elsewhere. However, note that the rebalancer can approve any amount of funds to the pools integrated (and can approve any amount of COMP to 0x for liquidation).

Please note that at the moment, smart contract upgrades are approved via a 3-of-5 multisig federation controlled by Rari's co-founders and partners. However, upgrades will become decentralized in the future via a governance protocol based on the Rari Governance Token (RGT).

Please note that using our web client online at [app.rari.capital](https://app.rari.capital) is not nearly as trustworthy as downloading, verifying, and using it offline. Lastly, the rebalancer is centralized, but it can only rebalance funds to different pools and currencies (with limits on slippage).

## Risk

We have covered security above, but see [our website](https://rari.capital/risks.html) for more information on the risks associated with supplying funds to Rari.

## Fees

See [this Notion article](https://www.notion.so/Fees-e4689d7b800f485098548dd9e9d0a69f) for more information about fees and where they go.

* A *9.5% performance fee* is deducted from all interest earned by REPT holders. This fee is liable to change in the future (but fees on past interest cannot be changed).
* There is *no withdrawal fee* deducted from withdrawals from the Rari Ethereum Pool.

## COMP

All [COMP (Compound's governance token)](https://compound.finance/governance/comp) earned by the fund is liquidated into additional interest for REPT holders approximately every 3 days.
