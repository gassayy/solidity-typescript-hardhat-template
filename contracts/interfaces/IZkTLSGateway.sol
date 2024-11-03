// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IZkTLSGateway {

	struct CallbackInfo {
		address caller; // original msg.sender
		address httpClient; // the HTTP client contract that made the request
		uint64 maxResponseBytes;
		uint256 fee;
		uint256 nonce;
        bytes signature;
	}

	event RequestTLSCallBegin(
		bytes32 indexed prover,
		string remote,
		string serverName,
		bytes encrypted_key,
		uint64 max_response_bytes
	);
	event RequestTLSCallSegment(bytes data, bool isEncrypted);
	event RequestTLSCallEnd(bytes32 indexed requestId);

	function requestTLSCall(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bytes[] calldata data,
		CallbackInfo calldata callbackInfo
	) external returns (bytes32 requestId);
}
