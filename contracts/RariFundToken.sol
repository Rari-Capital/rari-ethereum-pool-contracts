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
 * This file includes the Ethereum contract code for rETH, the ERC20 token contract accounting for the ownership of the funds invested in Rari Capital's RariFund.
 */

pragma solidity 0.5.17;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Mintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Burnable.sol";

// REFT

/**
 * @title RariFundToken (ETH Fund)
 * @dev REPT is the ERC20 token contract accounting for the ownership of Rari Ethereum Fund's funds.
 */
contract RariFundToken is Initializable, ERC20, ERC20Detailed, ERC20Mintable, ERC20Burnable {
    using SafeMath for uint256;

    /**
     * @dev Initializer for REPT.
     */
    function initialize() public initializer {
        ERC20Detailed.initialize("Rari Ethereum Pool Token", "REPT", 18);
        ERC20Mintable.initialize(msg.sender);
    }
}
