# Changelog

## `v1.2.0` (contracts not yet deployed; all code not yet pushed)

* Implemented lending via Alpha Homora (ibETH).
* Implemented lending via Cream Finance (crETH);
* Implemented lending via Harvest Finance (fWETH);
* Updated KeeperDAO implementation to use their new contracts and liquidate ROOK rewards.
* Added function to upgrade `RariFundController` by forwarding unliquidated governance tokens farmed via liquidity mining.
* Externalized `ZeroExExchangeController` library.
* Minor refactoring of code and improvements to code comments.

## `v1.1.0` (contracts deployed 2020-11-19; all code pushed 2020-11-25)

* Fixed bug in which the REPT amount burned for a withdrawal was less than expected due to incomplete accounting for unclaimed interest fees.
