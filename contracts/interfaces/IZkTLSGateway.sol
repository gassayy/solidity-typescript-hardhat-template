// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IZkTLSGateway {

	error ResponseExceedsMaxSize();
	error InsufficientGas();
	error InvalidRequestHash();
	error InsufficientPaidGas();
	error InsufficientTokenBalance();
	error InsufficientTokenAllowance();

	struct CallbackInfo {
		address caller;
		address httpClient;
		uint64 maxResponseBytes;
		uint256 fee;
		uint256 paidGas;
		uint256 nonce;
    bytes32 requestHash;
		bytes32 requestTemplateHash;
		bytes32 responseTemplateHash;
	}

	struct TemplatedRequest {
		bytes32 requestTemplateHash;
		bytes32 responseTemplateHash;
		bytes32[] fields;
		bytes[] values;
	}

	event RequestTLSCallBegin(
        bytes32 indexed requestId,
        bytes32 indexed prover,
        bytes32 requestTemplateHash,
        bytes32 responseTemplateHash,
        string remote,
        string serverName,
        bytes encryptedKey,
        uint64 maxResponseSize
    );
	event RequestTLSCallSegment(bytes32 indexed requestId, bytes data, bool isEncrypted);
  event RequestTLSCallTemplateField(bytes32 indexed requestId, bytes32 indexed field, bytes value, bool isEncrypted);
	event RequestTLSCallEnd(bytes32 indexed requestId);
	event GasUsed(bytes32 indexed requestId, uint256 paiedGas, uint256 gasUsed, uint256 gasPrice);



	function requestTLSCall(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bytes[] calldata data,
		uint256 fee,
		uint64 maxResponseBytes
	) external payable returns (bytes32 requestId);

	function requestTLSCallTemplate(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		TemplatedRequest calldata request,
		uint256 fee,
		uint64 maxResponseBytes
	) external payable returns (bytes32 requestId);
}
