// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

interface IZkTlsAccount {

	error FieldValueLengthMismatch();
	error InsufficientPaidGas();
	error InsufficientTokenBalance();
	error InsufficientTokenAllowance();
	error PaymentTokenTransferFailed();
	error GasRefundFailed();
	error UnauthorizedCaller();
	error InvalidResponseHandler();

	event PaymentInfo(
		uint256 prepaidGas,
		uint256 actualGas,
		uint256 prepaidFee,
		uint256 actualFee
	);

	struct TemplatedRequest {
		bytes32 requestTemplateHash;
		bytes32 responseTemplateHash;
		uint64[] fields;
		bytes[] values;
	}

	function requestTLSCallTemplate(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bool isEncryptedKey,
		TemplatedRequest calldata request,
		uint256 fee,
		uint256 maxResponseBytes
	) external payable returns (bytes32 requestId);

	function requestTLSCall(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bool isEncryptedKey,
		bytes[] calldata data,
		uint256 fee,
		uint256 maxResponseBytes
	) external payable returns (bytes32 requestId);

	function deliveryResponse(
		bytes32 requestId,
		bytes32 requestHash,
		bytes calldata response,
		uint256 paidGas,
		uint256 fee,
		uint256 actualUsedBytes
	) external payable;

}
