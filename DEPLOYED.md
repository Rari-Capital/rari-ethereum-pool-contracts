# Rari Ethereum Pool: Deployed Smart Contracts

As follows are all deployments of our smart contracts on the Ethereum mainnet. See [`API.md`](API.md) for reference on these contracts' public methods and [`USAGE.md`](USAGE.md) for instructions on how to use them.

## Latest Versions

### `RariFundController`

`RariFundController` holds supplied funds and is used by the rebalancer to deposit and withdraw from pools and exchange COMP.

**v1.2.0**: (to be deployed)

### `RariFundManager`

`RariFundManager` is the Rari Ethereum Pool's main contract: it handles deposits, withdrawals, ETH balances, interest, fees, etc.

**v1.1.0**: `0xD6e194aF3d9674b62D1b30Ec676030C23961275e`

Implementation contract: `0xce346aD7046222Fd119F6B715B6F60C0FDBFe796`

### `RariFundToken`

The Rari Ethereum Pool Token (RSPT) is an ERC20 token used to internally account for the ownership of funds supplied to the Rari Ethereum Pool.

**v1.0.0**: `0xCda4770d65B4211364Cb870aD6bE19E7Ef1D65f4`

Implementation contract: `0xB849Daff8045fc295aF2f6b4E27874914b5911C6`

### `RariFundProxy`

`RariFundProxy` includes wrapper functions built on top of `RariFundManager`: exchange and deposit, withdraw and exchange.

**v1.0.0**: `0xa3cc9e4B9784c80a05B3Af215C32ff223C3ebE5c`

## Older Versions

### `RariFundController`

* **v1.0.0**: `0xD9F223A36C2e398B0886F945a7e556B41EF91A3C`

### `RariFundManager`

* **v1.0.0**: `0xD6e194aF3d9674b62D1b30Ec676030C23961275e`
