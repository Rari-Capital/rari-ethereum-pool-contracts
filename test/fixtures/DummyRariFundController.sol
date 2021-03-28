/**
 * @file
 * @author David Lucid <david@rari.capital>
 *
 * @section LICENSE
 *
 * All rights reserved to David Lucid of David Lucid LLC.
 * Any disclosure, reproduction, distribution or other use of this code by any individual or entity other than David Lucid of David Lucid LLC, unless given explicit permission by David Lucid of David Lucid LLC, is prohibited.
 *
 * @section DESCRIPTION
 *
 * This file includes the Ethereum contract code for DummyRariFundController, a dummy upgrade of RariFundController for testing.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

/**
 * @title DummyRariFundController
 * @dev This contract is a dummy upgrade of RariFundController for testing.
 */
contract DummyRariFundController {
    /**
     * @dev Boolean to be checked on `upgradeFundController`.
     */
    bool public constant IS_RARI_FUND_CONTROLLER = true;

    /**
     * @dev Payable fallback function to receive ETH from old fund controller.
     */
    function () external payable { }

    /**
     * @dev Returns the fund controller's balance of the specified currency in the specified pool.
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `CompoundPoolController.getBalance`) potentially modifies the state.
     * @param pool The index of the pool.
     */
    function _getPoolBalance(uint8 pool) public returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the fund controller's balance of the specified currency in the specified pool.
     * @dev Ideally, we can add the view modifier, but Compound's `getUnderlyingBalance` function (called by `CompoundPoolController.getBalance`) potentially modifies the state.
     * @param pool The index of the pool.
     */
    function getPoolBalance(uint8 pool) public returns (uint256) {
        return _getPoolBalance(pool);
    }

    /**
     * @dev Return a boolean indicating if the fund controller has funds in `currencyCode` in `pool`.
     * @param pool The index of the pool.
     */
    function hasETHInPool(uint8 pool) external view returns (bool) {
        return false;
    }

    /**
     * @dev External getter function for `_supportedPools` array.
     */
    function getSupportedPools() external view returns (uint8[] memory) {
        return new uint8[](0);
    }
}
