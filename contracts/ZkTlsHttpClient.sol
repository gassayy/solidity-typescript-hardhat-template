// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IZkTLSGateway } from "./interfaces/IZkTLSGateway.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

abstract contract ZkTlsHttpClient {
	IZkTLSGateway private _gateway;
	address private immutable GATEWAY_ADDRESS;

	error Unauthorized();

	constructor(address gateway) {
		_gateway = IZkTLSGateway(gateway);
		GATEWAY_ADDRESS = gateway;
	}

	/**
   * [METHOD] [PATH] HTTP/1.1
   * [Headers]
   * [Blank Line]
   * [Request Body]
   * @dev Formats URL and server name into HTTP/1.1 request string with optional data
	 * @param method The HTTP method (GET or POST)
	 * @param remote The URL endpoint
	 * @param serverName The server name for TLS
	 * @param data Optional data to be included in the request body
	 * @return formatted HTTP/1.1 request string
	 */
	function _formatHttpRequest(
		string memory method,
		string memory remote,
		string memory serverName,
		bytes memory data
	) internal pure returns (bytes memory) {
		if (keccak256(bytes(method)) == keccak256(bytes("GET"))) {
			// GET requests shouldn't have a body
			return
				abi.encodePacked(
					method,
					" ",
					remote,
					" HTTP/1.1\r\n",
					"Host: ",
					serverName,
					"\r\n",
					"Connection: close\r\n",
					"\r\n"
				);
		} else {
			// POST and other methods can have a body
			return
				abi.encodePacked(
					method,
					" ",
					remote,
					" HTTP/1.1\r\n",
					"Host: ",
					serverName,
					"\r\n",
					"Content-Length: ",
					Strings.toString(data.length),
					"\r\n",
					"Connection: close\r\n",
					"\r\n",
					data
				);
		}
	}

	/**
	 * @dev Initiates a GET request through the ZK-TLS gateway
	 * @param maxResponseBytes Maximum size of the response in bytes
	 * @param remote The URL endpoint to send the request to
	 * @param serverName The server name for TLS verification
	 * @param encryptedKey The encrypted session key
	 * @param data The request data, including header, cookies etc (not used for now)
	 * @param signature Signature for request verification
	 * @param fee Fee paid for the request
	 * @return requestId Unique identifier for the request
	 */
	function _get(
		uint64 maxResponseBytes,
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bytes[] calldata data,
		bytes calldata signature,
		uint256 fee
	) internal returns (bytes32 requestId) {
		bytes memory formattedRequest = _formatHttpRequest(
			"GET",
			remote,
			serverName,
			""
		);

		IZkTLSGateway.CallbackInfo memory callbackInfo = IZkTLSGateway
			.CallbackInfo({
				caller: msg.sender,
				httpClient: address(this),
				maxResponseBytes: maxResponseBytes,
				nonce: block.number, // block number as nonce
				fee: fee,
				signature: signature
			});

		bytes[] memory requestData = new bytes[](1);
		requestData[0] = formattedRequest;

		return
			_gateway.requestTLSCall(
				remote,
				serverName,
				encryptedKey,
				requestData,
				callbackInfo
			);
	}

	/**
	 * @dev Initiates a POST request through the ZK-TLS gateway
	 * @param maxResponseBytes Maximum size of the response in bytes
	 * @param remote The URL endpoint to send the request to
	 * @param serverName The server name for TLS verification
	 * @param encryptedKey The encrypted session key
	 * @param data The request data to be posted
	 * @return requestId Unique identifier for the request
	 */
	function _post(
		uint64 maxResponseBytes,
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bytes[] calldata data
	) internal returns (bytes32 requestId) {
		bytes memory formattedRequest = _formatHttpRequest(
			"POST",
			remote,
			serverName,
			data[0] // Assuming first element contains the POST body
		);

		IZkTLSGateway.CallbackInfo memory callbackInfo = IZkTLSGateway
			.CallbackInfo({
				caller: msg.sender,
				httpClient: address(this),
				maxResponseBytes: maxResponseBytes,
				nonce: block.number, // Added nonce like in _get
				fee: 0, // Added fee parameter
				signature: "" // Added empty signature
			});
    
		bytes[] memory requestData = new bytes[](1);
		requestData[0] = formattedRequest;

		return
			_gateway.requestTLSCall(
				remote,
				serverName,
				encryptedKey,
				requestData,
				callbackInfo
			);
	}

	/**
	 * @dev This function is called by the gateway when a response is received.
	 */
	function deliveryResponse(
		bytes32 requestId,
		bytes[] calldata response
	) external payable virtual;
}
