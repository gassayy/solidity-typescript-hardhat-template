// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IZkTlsGateway } from "./interfaces/IZkTlsGateway.sol";
import { IZkTlsAccount } from "./interfaces/IZkTlsAccount.sol";

contract ZkTlsGateway is IZkTlsGateway, ReentrancyGuard {
	bytes32 private _gatewayHash;
	address private _verifier;
	address private _paymentToken;
	// @dev mapping of requestId to callbackInfo
	mapping(bytes32 => CallbackInfo) private _requestCallbacks;

	constructor(
		address forwardingAddress,
		address paymentToken,
		address verifier
	) {
		if (forwardingAddress == address(0)) revert InvalidForwardingAddress();
		_verifier = verifier;
		_paymentToken = paymentToken;
		_gatewayHash = keccak256(abi.encode(address(this)));
	}

	function estimateFee(
		uint256 maxResponseBytes
	) external pure returns (uint256) {
		return maxResponseBytes * 10;
	}

	function getConfiguration()
		external
		view
		returns (
			address gatewayHash,
			address paymentToken,
			address verifier
		)
	{
		return (address(this), _paymentToken, _verifier);
	}

	function _generateRequestId(address account, uint256 nonce) internal view returns (bytes32) {
		return keccak256(abi.encodePacked(address(this), account, nonce)); 
	}

	function _populateCallbackInfo(
		bytes32 requestId,
		bytes32 requestTemplateHash,
		bytes32 responseTemplateHash,
		uint256 requestBytes,
		uint256 fee,
		uint64 nonce,
		uint256 paidGas,
		uint256 maxResponseBytes,
		bytes calldata encryptedKey
	) internal view returns (CallbackInfo memory cb) {
		cb = CallbackInfo({
			// solhint-disable-next-line avoid-tx-origin
			caller: tx.origin,
			httpClient: msg.sender,
			requestBytes: requestBytes,
			maxResponseBytes: maxResponseBytes,
			nonce: nonce,
			fee: fee,
			paidGas: paidGas,
			requestHash: keccak256(
				abi.encode(requestId, msg.sender, encryptedKey, nonce)
			),
			requestTemplateHash: requestTemplateHash,
			responseTemplateHash: responseTemplateHash
		});
	}

	function requestTLSCallTemplate(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		IZkTlsAccount.TemplatedRequest calldata request,
		uint256 fee,
		uint64 nonce,
		uint256 maxResponseBytes
	) public payable returns (bytes32 requestId) {
		requestId = _generateRequestId(msg.sender, nonce);

		if (request.fields.length != request.values.length) {
			revert FieldValueLengthMismatch();
		}

		_requestCallbacks[requestId] = _populateCallbackInfo(
			requestId,
			request.requestTemplateHash,
			request.responseTemplateHash,
			0, // init requestBytes
			fee,
			nonce,
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
			_requestCallbacks[requestId].requestBytes += request.values[i].length;
			emit RequestTLSCallTemplateField(
				requestId,
				request.fields[i],
				request.values[i],
				encryptedKey.length > 0 ? true : false
			);
		}
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
		uint256 maxResponseBytes,
		uint64 nonce
	) public payable returns (bytes32 requestId) {
		requestId = _generateRequestId(msg.sender, nonce);

		_requestCallbacks[requestId] = _populateCallbackInfo(
			requestId,
			0x0, // requestTemplateHash is not used
			0x0, // responseTemplateHash is not used
			0, // init requestBytes as 0
			fee,
			nonce,
			msg.value, // paidGas amount
			maxResponseBytes,
			encryptedKey
		);

		emit RequestTLSCallBegin(
			requestId,
			0x0,	// prover is not used
			0x0, // requestTemplateHash is not used
			0x0, // responseTemplateHash is not used
			remote,
			serverName,
			encryptedKey,
			maxResponseBytes
		);

		for (uint256 i = 0; i < data.length; i++) {
			bool isEncrypted = i % 2 == 0;
			_requestCallbacks[requestId].requestBytes += data[i].length;
			emit RequestTLSCallSegment(requestId, data[i], !isEncrypted);
		}
	}

	function deliveryResponse(
		bytes32 requestId,
		bytes32 requestHash,
		bytes calldata response,
		// solhint-disable-next-line no-unused-vars
		bytes calldata proofs
	) public payable nonReentrant {
		
		CallbackInfo memory cb = _requestCallbacks[requestId];

		// Use the custom error instead of require
		if (response.length > cb.maxResponseBytes) {
			revert ResponseExceedsMaxSize();
		}
		// check if requestHash is valid
		if (cb.requestHash != requestHash) revert InvalidRequestHash();
		
		uint256 actualUsedBytes = response.length + cb.requestBytes;

		// TODO: call zktls verifier
		bytes memory data = abi.encodeWithSignature(
			"deliveryResponse(bytes32,bytes32,bytes,uint256,uint256,uint256)",
			requestId,
			requestHash,
			response,
			cb.paidGas,
			cb.fee,
			actualUsedBytes
		);
		Address.functionCall(cb.httpClient, data);
		delete _requestCallbacks[requestId];
	}

}
