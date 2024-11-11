// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IZkTlsAccount } from "./interfaces/IZkTlsAccount.sol";
import { IZkTlsGateway } from "./interfaces/IZkTlsGateway.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { IZkTlsResponseHandler } from "./interfaces/IZkTlsResponseHandler.sol";

contract SimpleZkTlsAccount is IZkTlsAccount {
	address private _manager;
	address private _gateway;
	address private _responseHandler;
	address private _paymentToken;
	uint64 private _nonce;
	// used for upgrad
	uint8 public constant VERSION = 1;

	constructor(
		address manager,
		address gateway,
		address paymentToken,
		address responseHandler
	) {
		_manager = manager;
		_gateway = gateway;
		_paymentToken = paymentToken;
		_responseHandler = responseHandler;
		_nonce = 0;
	}

	function nextNonce() public view returns (uint256) {
		return _nonce;
	}

	function requestTLSCall(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bytes[] calldata data,
		uint256 fee,
		uint64 maxResponseBytes
	) external payable returns (bytes32 requestId) {
		// approve the gateway to spend/transfer the fee
		IERC20(_paymentToken).approve(_gateway, fee);
		// send request to gateway
		requestId = IZkTlsGateway(_gateway).requestTLSCall{ value: msg.value }(
			remote,
			serverName,
			encryptedKey,
			data,
			fee,
			maxResponseBytes,
			_nonce
		);

		_nonce++;
	}

	function requestTLSCallTemplate(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		TemplatedRequest calldata request,
		uint256 fee,
		uint64 maxResponseBytes
	) public payable returns (bytes32 requestId) {
		// approve the gateway to spend/transfer the fee
		IERC20(_paymentToken).approve(_gateway, fee);
		// send request to gateway
		requestId = IZkTlsGateway(_gateway).requestTLSCallTemplate{
			value: msg.value
		}(
			remote,
			serverName,
			encryptedKey,
			request,
			fee,
			maxResponseBytes,
			_nonce
		);

		_nonce++;
	}

	// callback from gateway
	function deliveryResponse(
		bytes32 requestId,
		bytes32 requestHash,
		bytes calldata response
	) external payable {
		uint256 start = gasleft();
		bytes memory data = abi.encodeWithSelector(
			IZkTlsResponseHandler.handleResponse.selector,
			requestId,
			requestHash,
			response
		);
		Address.functionCall(_responseHandler, data);
		uint256 usedGas = start - gasleft();
		_transferFeeFromAccount(address(this), usedGas, usedGas, 0);
	}

	function _transferFeeFromAccount(
		address zkTlsAccount,
		uint256 paidGas,
		uint256 usedGas,
		uint256 fee
	) internal {
		uint256 allowed = IERC20(_paymentToken).balanceOf(address(this));
		if (allowed < fee) revert InsufficientTokenAllowance();		
		if (paidGas < usedGas) revert InsufficientPaidGas();

		bool success = IERC20(_paymentToken).transferFrom(
			zkTlsAccount,
			address(this),
			fee
		);
		if (!success) revert PaymentTokenTransferFailed();
		if (usedGas <= paidGas) {
			(bool sent, ) = zkTlsAccount.call{ value: msg.value }("");
			if (!sent) revert GasRefundFailed();
		}
	}
}
