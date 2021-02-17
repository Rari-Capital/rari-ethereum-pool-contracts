// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Council <council@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.5.17;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";

import "@0x/contracts-erc20/contracts/src/interfaces/IEtherToken.sol";

import "../../contracts/lib/pools/AlphaPoolController.sol";

/// @title MockEnzymeComptroller Contract
/// @author Enzyme Council <security@enzyme.finance>
/// @author David Lucid <david@rari.capital>
/// @notice Mock version of Enzyme's core logic library shared by all funds built for the Rari Ethereum Pool
contract MockEnzymeComptroller is ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ////////////////
    // ACCOUNTING //
    ////////////////

    /// @notice Calculates the gross value of 1 unit of shares in the fund's denomination asset
    /// @param _requireFinality True if all assets must have exact final balances settled
    /// @return grossShareValue_ The amount of the denomination asset per share
    /// @return isValid_ True if the conversion rates to derive the value are all valid
    /// @dev Does not account for any fees outstanding.
    function calcGrossShareValue(bool _requireFinality)
        public
        returns (uint256 grossShareValue_, bool isValid_)
    {
        uint256 eth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).balanceOf(address(this)).add(AlphaPoolController.getBalance());
        return (eth > 0 && totalSupply() > 0 ? eth.mul(1e18).div(totalSupply()) : 1e18, true);
    }

    ///////////////////
    // PARTICIPATION //
    ///////////////////

    // BUY SHARES

    /// @notice Buys shares in the fund for multiple sets of criteria
    /// @param _buyers The accounts for which to buy shares
    /// @param _investmentAmounts The amounts of the fund's denomination asset
    /// with which to buy shares for the corresponding _buyers
    /// @param _minSharesQuantities The minimum quantities of shares to buy
    /// with the corresponding _investmentAmounts
    /// @return sharesReceivedAmounts_ The actual amounts of shares received
    /// by the corresponding _buyers
    /// @dev Param arrays have indexes corresponding to individual __buyShares() orders.
    function buyShares(
        address[] calldata _buyers,
        uint256[] calldata _investmentAmounts,
        uint256[] calldata _minSharesQuantities
    ) external returns (uint256[] memory sharesReceivedAmounts_)
    {
        IEtherToken weth = IEtherToken(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        weth.transferFrom(msg.sender, address(this), _investmentAmounts[0]);
        uint256 randomPercentage = (uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 100) + 1;
        (uint256 grossShareValue_, ) = calcGrossShareValue(true);
        sharesReceivedAmounts_[0] = _investmentAmounts[0].mul(1e18).div(grossShareValue_);
        uint256 alphaDeposit = weth.balanceOf(address(this)).mul(randomPercentage).div(100);
        weth.withdraw(alphaDeposit);
        AlphaPoolController.deposit(alphaDeposit);
        _mint(_buyers[0], sharesReceivedAmounts_[0]);
    }

    // REDEEM SHARES

    /// @notice Redeem all of the sender's shares for a proportionate slice of the fund's assets
    /// @return payoutAssets_ The assets paid out to the redeemer
    /// @return payoutAmounts_ The amount of each asset paid out to the redeemer
    /// @dev See __redeemShares() for further detail
    function redeemShares()
        external
        returns (address[] memory payoutAssets_, uint256[] memory payoutAmounts_)
    {
        return _redeemShares(balanceOf(msg.sender));
    }

    /// @notice Redeem a specified quantity of the sender's shares for a proportionate slice of
    /// the fund's assets, optionally specifying additional assets and assets to skip.
    /// @param _sharesQuantity The quantity of shares to redeem
    /// @param _additionalAssets Additional (non-tracked) assets to claim
    /// @param _assetsToSkip Tracked assets to forfeit
    /// @return payoutAssets_ The assets paid out to the redeemer
    /// @return payoutAmounts_ The amount of each asset paid out to the redeemer
    /// @dev Any claim to passed _assetsToSkip will be forfeited entirely. This should generally
    /// only be exercised if a bad asset is causing redemption to fail.
    function redeemSharesDetailed(
        uint256 _sharesQuantity,
        address[] calldata _additionalAssets,
        address[] calldata _assetsToSkip
    )
        external
        returns (address[] memory payoutAssets_, uint256[] memory payoutAmounts_)
    {
        uint256 sharesBalance = balanceOf(msg.sender);
        require(_sharesQuantity <= sharesBalance, "Shares quantity must be less than or equal to balance.");
        return _redeemShares(_sharesQuantity);
    }

    function _redeemShares(uint256 _sharesQuantity)
        private
        returns (address[] memory payoutAssets_, uint256[] memory payoutAmounts_)
    {
        (uint256 grossShareValue_, ) = calcGrossShareValue(true);
        uint256 payoutEth = _sharesQuantity.mul(grossShareValue_).div(1e18);
        payoutAssets_[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
        payoutAssets_[1] = 0x67B66C99D3Eb37Fa76Aa3Ed1ff33E8e39F0b9c7A; // ibETH
        uint256 wethBalance = IERC20(payoutAssets_[0]).balanceOf(address(this));
        uint256 ibEthBalance = IERC20(payoutAssets_[1]).balanceOf(address(this));
        uint256 alphaEthBalance = AlphaPoolController.getBalance();
        uint256 totalEth = wethBalance.add(alphaEthBalance);
        payoutAmounts_[0] = payoutEth.mul(wethBalance).div(totalEth);
        payoutAmounts_[1] = payoutEth.mul(ibEthBalance).div(totalEth); // Total ETH payout * (ETH supplied to Alpha / total ETH supplied) * (ibETH balance / ETH supplied to Alpha)
        IERC20(payoutAssets_[0]).transfer(msg.sender, payoutAmounts_[0]);
        IERC20(payoutAssets_[1]).transfer(msg.sender, payoutAmounts_[1]);
    }

    ///////////////////
    // STATE GETTERS //
    ///////////////////

    /// @notice Gets the `vaultProxy` variable
    /// @return vaultProxy_ The `vaultProxy` variable value
    function getVaultProxy() external view returns (address vaultProxy_) {
        return address(this);
    }
}
