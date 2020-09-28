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
 * This file includes the Ethereum contract code for RariFundProxy, which faciliates pre-deposit exchanges and post-withdrawal exchanges.
 */

pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/drafts/SignedSafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/GSN/GSNRecipient.sol";
import "@openzeppelin/contracts/cryptography/ECDSA.sol";

import "@0x/contracts-exchange-libs/contracts/src/LibOrder.sol";
import "@0x/contracts-erc20/contracts/src/interfaces/IEtherToken.sol";

import "./lib/exchanges/ZeroExExchangeController.sol";
import "./RariFundManager.sol";

/**
 * @title RariFundProxy
 * @dev This contract faciliates deposits to RariFundManager from exchanges and withdrawals from RariFundManager for exchanges.
 */

contract RariFundProxy is Ownable, GSNRecipient {
    using SafeMath for uint256;
    using SignedSafeMath for int256;
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    /**
     * @notice Package version of `rari-eth-contracts` when this contract was deployed.
     */
    string public constant VERSION = "1.0.0";


    /**
     * @dev Maps ERC20 token contract addresses to supported currency codes.
     */
    mapping(string => address) private _erc20Contracts;

    /**
     * @dev Constructor that sets supported ERC20 token contract addresses.
     */
    constructor () public {

    }

    /**
     * @dev Address of the RariFundManager.
     */
    address payable private _rariFundManagerContract;

    /**
     * @dev Contract of the RariFundManager.
     */
    RariFundManager private _rariFundManager;

    /**
     * @dev Address of the trusted GSN signer.
     */
    address private _gsnTrustedSigner;

    /**
     * @dev Emitted when the RariFundManager of the RariFundProxy is set.
     */
    event FundManagerSet(address newContract);


    address constant private WETH_CONTRACT = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    IEtherToken constant private _weth = IEtherToken(WETH_CONTRACT);


    /**
     * @dev Sets or upgrades the RariFundManager of the RariFundProxy.
     * @param newContract The address of the new RariFundManager contract.
     */
    function setFundManager(address payable newContract) external onlyOwner {
        // Approve maximum output tokens to RariFundManager for deposit
        // see safeApprove in IERC20
        if (_rariFundManagerContract != address(0)) _weth.approve(_rariFundManagerContract, 0);
        if (newContract != address(0)) _weth.approve(newContract, uint256(-1));

        _rariFundManagerContract = newContract;
        _rariFundManager = RariFundManager(_rariFundManagerContract);
        emit FundManagerSet(newContract);
    }

    

    /**
     * @dev Emitted when the trusted GSN signer of the RariFundProxy is set.
     */
    event GsnTrustedSignerSet(address newAddress);

    /**
     * @dev Sets or upgrades the trusted GSN signer of the RariFundProxy.
     * @param newAddress The Ethereum address of the new trusted GSN signer.
     */
    function setGsnTrustedSigner(address newAddress) external onlyOwner {
        _gsnTrustedSigner = newAddress;
        emit GsnTrustedSignerSet(newAddress);
    }

    /**
     * @dev Payable fallback function called by 0x exchange to refund unspent protocol fee.
     */
    function () external payable { }

    /**
     * @dev Emitted when funds have been exchanged before being deposited via RariFundManager.
     * If exchanging from ETH, `inputErc20Contract` = address(0).
     */
    event PreDepositExchange(address indexed inputErc20Contract, address indexed payee, uint256 makerAssetFilledAmount, uint256 depositAmount);

    /**
     * @dev Emitted when funds have been exchanged after being withdrawn via RariFundManager.
     * If exchanging from ETH, `outputErc20Contract` = address(0).
     */
    event PostWithdrawalExchange(string indexed inputCurrencyCode, address indexed outputErc20Contract, address indexed payee, uint256 withdrawalAmount, uint256 takerAssetFilledAmount);

    /**
     * @notice Exchanges and deposits funds to RariFund in exchange for REFT.
     * You can retrieve orders from the 0x swap API (https://0x.org/docs/api#get-swapv0quote). See the web client for implementation.
     * Please note that you must approve RariFundProxy to transfer at least `inputAmount`.
     * You also must input at least enough ETH to cover the protocol fee (and enough to cover `orders` ).
     * @dev We should be able to make this function external and use calldata for all parameters, but Solidity does not support calldata structs (https://github.com/ethereum/solidity/issues/5479).
     * @param inputErc20Contract The ERC20 contract address of the token to be exchanged. Set to address(0) to input ETH.
     * @param inputAmount The amount of tokens to be exchanged (including taker fees).
     * @param orders The limit orders to be filled in ascending order of the price you pay.
     * @param signatures The signatures for the orders.
     * @param takerAssetFillAmount The amount of the taker asset to sell (excluding taker fees).
     * @return Boolean indicating success.
     (0, 1000, "DAI", ...)
     */
    function exchangeAndDeposit(address inputErc20Contract, uint256 inputAmount, LibOrder.Order[] memory orders, bytes[] memory signatures, uint256 takerAssetFillAmount) public returns (bool) {
        // Input validation
        require(_rariFundManagerContract != address(0), "Fund manager contract not set. This may be due to an upgrade of this proxy contract.");
        require(inputAmount > 0, "Input amount must be greater than 0.");
        address outputErc20Contract = WETH_CONTRACT;
        require(outputErc20Contract != address(0), "Invalid output currency code.");
        require(orders.length > 0, "Orders array is empty.");
        require(orders.length == signatures.length, "Length of orders and signatures arrays must be equal.");
        require(takerAssetFillAmount > 0, "Taker asset fill amount must be greater than 0.");


        // Transfer input tokens from msg.sender if not inputting ETH
        IERC20(inputErc20Contract).safeTransferFrom(msg.sender, address(this), inputAmount); // The user must approve the transfer of tokens beforehand

        if (inputErc20Contract == WETH_CONTRACT) {
            // convert WETH to ETH
            _weth.withdraw(inputAmount);
            // Deposit ETH
            require(_rariFundManager.depositTo.value(inputAmount)(msg.sender));

            return true;
        }


        // Approve and exchange tokens
        if (inputAmount > ZeroExExchangeController.allowance(inputErc20Contract)) ZeroExExchangeController.approve(inputErc20Contract, uint256(-1));

        uint256[2] memory filledAmounts = ZeroExExchangeController.marketSellOrdersFillOrKill(orders, signatures, takerAssetFillAmount, inputErc20Contract == address(0) ? msg.value.sub(inputAmount) : msg.value);

        if (inputErc20Contract == address(0)) {
            // Unwrap unused ETH
            uint256 wethBalance = _weth.balanceOf(address(this));
            if (wethBalance > 0) _weth.withdraw(wethBalance);
        } else {
            // Refund unused input tokens
            IERC20 inputToken = IERC20(inputErc20Contract);
            uint256 inputTokenBalance = inputToken.balanceOf(address(this));
            if (inputTokenBalance > 0) inputToken.safeTransfer(msg.sender, inputTokenBalance);
        }

        // Emit event
        emit PreDepositExchange(inputErc20Contract, msg.sender, filledAmounts[0], filledAmounts[1]);

        // Deposit output tokens
        require(_rariFundManager.depositTo.value(filledAmounts[1])(msg.sender), "Deposit failed.");

        // Refund unused ETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) msg.sender.transfer(ethBalance);

        return true;
    }
    
    /**
     * @notice Deposits funds to RariFund in exchange for REFT (with GSN support).
     * You may only deposit ETH.
     * Please note that you must approve RariFundProxy to transfer at least `amount`.
     * @return Boolean indicating success.
     */
    function deposit() payable external returns (bool) {
        require(msg.value > 0, "Must deposit more than 0 eth");
        return _rariFundManager.depositTo.value(msg.value)(_msgSender());
    }

    /**
     * @dev Ensures that only transactions with a trusted signature can be relayed through the GSN.
     */
    function acceptRelayedCall(
        address relay,
        address from,
        bytes calldata encodedFunction,
        uint256 transactionFee,
        uint256 gasPrice,
        uint256 gasLimit,
        uint256 nonce,
        bytes calldata approvalData,
        uint256
    ) external view returns (uint256, bytes memory) {
        bytes memory blob = abi.encodePacked(
            relay,
            from,
            encodedFunction,
            transactionFee,
            gasPrice,
            gasLimit,
            nonce, // Prevents replays on RelayHub
            getHubAddr(), // Prevents replays in multiple RelayHubs
            address(this) // Prevents replays in multiple recipients
        );
        if (keccak256(blob).toEthSignedMessageHash().recover(approvalData) != _gsnTrustedSigner) return _rejectRelayedCall(0);
        if (_gsnTrustedSigner == address(0)) return _rejectRelayedCall(1);
        return _approveRelayedCall();
    }

    /**
     * @dev Code executed before processing a call relayed through the GSN.
     */
    function _preRelayedCall(bytes memory) internal returns (bytes32) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Code executed after processing a call relayed through the GSN.
     */
    function _postRelayedCall(bytes memory, bool, uint256, bytes32) internal {
        // solhint-disable-previous-line no-empty-blocks
    }
}
