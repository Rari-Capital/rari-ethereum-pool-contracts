# Changelog

## `v1.2.0` (contracts deployed 2020-02-08; all code pushed 2020-02-16)

* Implemented lending via Enzyme Finance.
* Implemented lending via Alpha Homora (ibETH).
* Updated KeeperDAO implementation to use their new contracts and liquidate ROOK rewards.
* Check `fundDisabled` in `RariFundManager.upgradeFundController`.

## `v1.1.0` (contracts deployed 2020-11-19; all code pushed 2020-11-25)

* Fixed bug in which the REPT amount burned for a withdrawal was less than expected due to incomplete accounting for unclaimed interest fees.
