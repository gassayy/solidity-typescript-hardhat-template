// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IZkTlsAccount } from "./interfaces/IZkTlsAccount.sol";
import { IZkTlsGateway } from "./interfaces/IZkTlsGateway.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { IZkTlsResponseHandler } from "./interfaces/IZkTlsResponseHandler.sol";

import "hardhat/console.sol";

contract SimpleZkTlsAccount is IZkTlsAccount, Initializable {
	address private _gateway;
	address private _responseHandler;
	address private _paymentToken;
	uint64 private _nonce;
	// used for upgrad
	uint8 public constant VERSION = 1;

	function initialize(
		address gateway,
		address paymentToken,
		address responseHandler
	) public initializer {
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
		uint256 maxResponseBytes
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
		uint256 maxResponseBytes
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
			_nonce,
			maxResponseBytes
		);

		_nonce++;
	}

	// callback from gateway
	function deliveryResponse(
		bytes32 requestId,
		bytes32 requestHash,
		bytes calldata response,
		uint256 paidGas,
		uint256 fee,
		uint256 actualUsedBytes // response bytes + response bytes
	) external payable {
		if (msg.sender != _gateway) revert UnauthorizedCaller();
		
		uint256 start = gasleft();
		bytes memory data = abi.encodeWithSelector(
			IZkTlsResponseHandler.handleResponse.selector,
			requestId,
			requestHash,
			response
		);
		Address.functionCall(_responseHandler, data);
		uint256 usedGas = start - gasleft();
		_transferFeeFromAccount(_gateway, paidGas, usedGas, fee, actualUsedBytes);
	}

	function _transferFeeFromAccount(
		address zkTlsAccount,
		uint256 paidGas,
		uint256 usedGas,
		uint256 fee,
		uint256 actualUsedBytes
	) internal {
		uint256 allowed = IERC20(_paymentToken).allowance(address(this), _gateway);
		if (allowed < fee) revert InsufficientTokenAllowance();		
		if (paidGas < usedGas) revert InsufficientPaidGas();
		// transfer fee to gateway
		bool success = IERC20(_paymentToken).transferFrom(
			zkTlsAccount,
			_gateway,
			fee
		);

		uint256 refund = fee - (actualUsedBytes * IZkTlsGateway(_gateway).getTokenWeiPerBytes());

		// refund unused fee
		if (refund > 0) {
			success = IERC20(_paymentToken).transfer(zkTlsAccount, refund);
		}
		if (!success) revert PaymentTokenTransferFailed();

		// refund unused gas	
		if (usedGas <= paidGas) {
			(bool sent, ) = zkTlsAccount.call{ value: paidGas - usedGas }("");
			if (!sent) revert GasRefundFailed();
		}
	}
}
