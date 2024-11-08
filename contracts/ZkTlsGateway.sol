// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IZkTLSGateway } from "./interfaces/IZkTLSGateway.sol";
import { ZkTlsRequestIDBase } from "./uuid/ZkTlsRequestIDBase.sol";
import { IForwarding } from "./interfaces/IForwarding.sol";

contract ZkTLSGateway is IZkTLSGateway, ZkTlsRequestIDBase, ReentrancyGuard {
	
	uint256 private _nonce;
	bytes32 private _gatewayHash;
	IForwarding private _forwarding;
	address private _forwardingAddress;
	IERC20 private _paymentToken;
	// @dev mapping of requestId to callbackInfo
	mapping(bytes32 => CallbackInfo) private _requestCallbacks;

	

	constructor(address forwardingAddress, address paymentToken) {
		if (forwardingAddress == address(0)) revert InvalidForwardingAddress();
		_forwardingAddress = forwardingAddress;
		_forwarding = IForwarding(forwardingAddress);
		_paymentToken = IERC20(paymentToken);
		_gatewayHash = keccak256(abi.encode(address(this)));
		_nonce = 0;
	}

	function _generateRequestId() internal view returns (bytes32) {
		uint256 zkTlsInputSeed = makeZkTlsInputSeed(msg.sender, _nonce);
		return makeRequestId(_gatewayHash, zkTlsInputSeed);
	}

	function _populateCallbackInfo(
		bytes32 requestId,
		bytes32 requestTemplateHash,
		bytes32 responseTemplateHash,
		uint256 fee,
		uint256 paidGas,
		uint64 maxResponseBytes,
		bytes calldata encryptedKey
	) internal view returns (CallbackInfo memory cb) {
		cb = CallbackInfo({
			// solhint-disable-next-line avoid-tx-origin
			caller: tx.origin,
			httpClient: msg.sender,
			maxResponseBytes: maxResponseBytes,
			nonce: block.number,
			fee: fee,
			paidGas: paidGas,
			requestHash: keccak256(abi.encode(requestId, msg.sender, encryptedKey)),
			requestTemplateHash: requestTemplateHash,
			responseTemplateHash: responseTemplateHash
		});
	}

	function requestTLSCallTemplate(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		TemplatedRequest calldata request,
		uint256 fee,
		uint64 maxResponseBytes
	) public payable returns (bytes32 requestId) {
		requestId = _generateRequestId();

		if (request.fields.length != request.values.length) {
			revert FieldValueLengthMismatch();
		}

		_requestCallbacks[requestId] = _populateCallbackInfo(
			requestId,
			request.requestTemplateHash,
			request.responseTemplateHash,
			fee,
			msg.value, // paidGas amount
			maxResponseBytes,
			encryptedKey
		);

		emit RequestTLSCallBegin(
			requestId,
			request.requestTemplateHash,
			0x0, // prover is not used
			request.responseTemplateHash,
			remote,
			serverName,
			encryptedKey,
			maxResponseBytes
		);

		for (uint256 i = 0; i < request.fields.length; i++) {
			emit RequestTLSCallTemplateField(
				requestId,
				request.fields[i],
				request.values[i],
				encryptedKey.length > 0 ? true : false
			);
		}
		// post increment nonce
		_nonce++;
	}

	/**
	 * @dev Initiates a request through the ZK-TLS gateway
	 * @param remote The URL endpoint to send the request to
	 * @param serverName The server name for TLS verification
	 * @param encryptedKey The encrypted session key
	 * @param data The request data
	 * @return requestId Unique identifier for the request
	 */
	function requestTLSCall(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bytes[] calldata data,
		uint256 fee,
		uint64 maxResponseBytes
	) public payable returns (bytes32 requestId) {
		requestId = _generateRequestId();

		_requestCallbacks[requestId] = _populateCallbackInfo(
			requestId,
			0x0, // requestTemplateHash is not used
			0x0, // responseTemplateHash is not used
			fee,
			msg.value,
			maxResponseBytes,
			encryptedKey
		);

		emit RequestTLSCallBegin(
			requestId,
			0x0, // prover is not used
			0x0, // requestTemplateHash is not used
			0x0, // responseTemplateHash is not used
			remote,
			serverName,
			encryptedKey,
			maxResponseBytes
		);

		for (uint256 i = 0; i < data.length; i++) {
			bool isEncrypted = i % 2 == 0;
			emit RequestTLSCallSegment(requestId, data[i], !isEncrypted);
		}
		// post increment nonce
		_nonce++;
	}

	function deliveryResponse(
		bytes32 requestId,
		bytes32 requestHash,
		bytes calldata response
	) public payable nonReentrant {
		IZkTLSGateway.CallbackInfo memory cb = _requestCallbacks[requestId];

		// Use the custom error instead of require
		if (response.length > cb.maxResponseBytes) {
			revert ResponseExceedsMaxSize();
		}
		uint256 startGas = gasleft();
		bytes memory callData = abi.encodeWithSignature(
			"deliveryResponse(bytes32,bytes32,bytes)",
			requestId,
			requestHash,
			response
		);

		IForwarding.ForwardRequest memory request = IForwarding.ForwardRequest({
			from: cb.caller,
			to: cb.httpClient,
			value: cb.fee,
			gas: cb.paidGas,
			nonce: cb.nonce,
			data: callData
		});
		// TODO: verify requestHash
		_forwarding.execute(request, bytes("hello world"));
		uint256 endGas = gasleft();
		uint256 usedGasAmount = _calculateGasUsedAmount(startGas - endGas);
		emit GasUsed(requestId, cb.paidGas, usedGasAmount, tx.gasprice);
		// transfer the fee to the caller
		_transferFee(cb.httpClient, cb.paidGas, usedGasAmount, cb.fee);
		// delete the callback info
		delete _requestCallbacks[requestId];
	}

	function _calculateGasUsedAmount(
		uint256 gasUsed
	) internal view returns (uint256) {
		return gasUsed * tx.gasprice;
	}

	function _transferFee(
		address httpClient,
		uint256 paidGas,
		uint256 usedGas,
		uint256 fee
	) internal {
		uint256 clientTokenBalance = _paymentToken.balanceOf(httpClient);

		if (paidGas < usedGas) revert InsufficientPaidGas();
		if (clientTokenBalance < fee) revert InsufficientTokenBalance();

		uint256 allowed = _paymentToken.allowance(httpClient, address(this));
		if (allowed < fee) revert InsufficientTokenAllowance();

		bool success = _paymentToken.transferFrom(
			httpClient,
			address(this),
			fee
		);
		if (!success) revert PaymentTokenTransferFailed();
		if (usedGas <= paidGas) {
			(bool sent, ) = httpClient.call{ value: msg.value }("");
			if (!sent) revert GasRefundFailed();
		}
	}
}
