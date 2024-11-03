// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IZkTLSGateway} from "./interfaces/IZkTLSGateway.sol";
import {ZkTlsRequestIDBase} from "./uuid/ZkTlsRequestIDBase.sol";
import { IForwarding } from "./interfaces/IForwarding.sol";
import { ZkTlsHttpClient } from "./ZkTlsHttpClient.sol";

contract ZkTLSGateway is IZkTLSGateway, ZkTlsRequestIDBase {

  uint256 private _nonce;
  bytes32 private _gatewayHash;
	IForwarding private _forwarding;	
	address private _forwardingAddress;
	// @dev mapping of requestId to callbackInfo
	mapping(bytes32 => CallbackInfo) private _requestCallbacks;

	constructor(address forwardingAddress) {
		require(forwardingAddress != address(0), "Invalid forwarding address");
		_forwardingAddress = forwardingAddress;
		_forwarding = IForwarding(forwardingAddress);
		_gatewayHash = keccak256(abi.encode(address(this)));
		_nonce = 0;
	}

	/**
	 * @dev Initiates a request through the ZK-TLS gateway
	 * @param remote The URL endpoint to send the request to
	 * @param serverName The server name for TLS verification
	 * @param encryptedKey The encrypted session key
	 * @param data The request data
	 * @param callbackInfo Callback information for the request
	 * @return requestId Unique identifier for the request
	 */
	function requestTLSCall(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bytes[] calldata data,
		CallbackInfo calldata callbackInfo
	) public returns (bytes32 requestId) {

		uint256 zkTlsInputSeed = makeZkTlsInputSeed(msg.sender, _nonce);
		requestId = makeRequestId(_gatewayHash, zkTlsInputSeed);

		_requestCallbacks[requestId] = callbackInfo;

		emit RequestTLSCallBegin(
			0x0, // prover is not used
			remote,
			serverName,
			encryptedKey,
      callbackInfo.maxResponseBytes
		);

		for (uint256 i = 0; i < data.length; i++) {
			bool isEncrypted = i % 2 == 0;
			emit RequestTLSCallSegment(data[i], !isEncrypted);
		}
    // post increment nonce
    _nonce++;
	}

	function deliveryResponse(bytes32 requestId, bytes[] calldata response) public payable {
		IZkTLSGateway.CallbackInfo memory info = _requestCallbacks[requestId];

		// Calculate total response length
		uint256 totalLength = 0;
		for (uint256 i = 0; i < response.length; i++) {
			totalLength += response[i].length;
		}
		// Check if response length exceeds maximum
		require(totalLength <= info.maxResponseBytes, "Response exceeds maximum allowed size");

		bytes memory callData = abi.encodeWithSignature("deliveryResponse(bytes32,bytes[])", requestId, response);
		// (bool success, ) = info.httpClient.call{gas: 50000}(callData);
		// require(success, "Gas estimation failed");

		IForwarding.ForwardRequest memory request = IForwarding.ForwardRequest({
			from: info.caller,
			to: info.httpClient,
			value: info.fee,
			gas: 0, // estimatedGas here???
			nonce: info.nonce,
			data: callData
		});
		_forwarding.execute(request, info.signature);
	}

}
