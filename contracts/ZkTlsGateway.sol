// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IZkTlsGateway } from "./interfaces/IZkTlsGateway.sol";
import { IZkTlsAccount } from "./interfaces/IZkTlsAccount.sol";
import { IZkTlsManager } from "./interfaces/IZkTlsManager.sol";

contract ZkTlsGateway is
	IZkTlsGateway,
	Initializable,
	UUPSUpgradeable,
	OwnableUpgradeable,
	ReentrancyGuardUpgradeable
{
	address private _manager;
	address private _verifier;
	address private _paymentToken;
	uint256 private _tokenWeiPerBytes;
	// @dev mapping of requestId to callbackInfo
	mapping(bytes32 => CallbackInfo) private _requestCallbacks;

	function initialize(
		address manager,
		uint256 tokenWeiPerBytes,
		address paymentToken,
		address verifier,
		address owner
	) public initializer {
		__UUPSUpgradeable_init();
		__ReentrancyGuard_init();
		_manager = manager;
		_verifier = verifier;
		_tokenWeiPerBytes = tokenWeiPerBytes;
		_paymentToken = paymentToken;
		__Ownable_init(owner);
	}

	function _authorizeUpgrade(
		address newImplementation
	) internal override onlyOwner {
		// TODO: add upgrade logic if needed
	}

	function estimateFee(
		uint256 requestBytes,
		uint256 maxResponseBytes
	) external view returns (uint256) {
		return (requestBytes + maxResponseBytes) * _tokenWeiPerBytes;
	}

	function getConfiguration()
		external
		view
		returns (address manager, address paymentToken, address verifier)
	{
		return (_manager, _paymentToken, _verifier);
	}

	function _generateRequestId(
		address account,
		uint256 nonce
	) internal view returns (bytes32) {
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
		if (!IZkTlsManager(_manager).checkAccess(msg.sender, address(this))) {
			revert UnauthorizedAccess();
		}

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
			0x0, // prover is not used
			request.requestTemplateHash,
			request.responseTemplateHash,
			remote,
			serverName,
			encryptedKey,
			maxResponseBytes
		);

		for (uint256 i = 0; i < request.fields.length; i++) {
			_requestCallbacks[requestId].requestBytes += request
				.values[i]
				.length;
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
		if (!IZkTlsManager(_manager).checkAccess(msg.sender, address(this))) {
			revert UnauthorizedAccess();
		}
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
			_requestCallbacks[requestId].requestBytes += data[i].length;
			emit RequestTLSCallSegment(requestId, data[i], !isEncrypted);
		}
	}

	/**
	 * @notice Retrieves the current rate of tokens per byte.
	 * @return uint256 The rate of tokens per byte.
	 */
	function getTokenWeiPerBytes() external view returns (uint256) {
		return _tokenWeiPerBytes;
	}

	/**
	 * @notice Updates the rate of tokens per byte.
	 * @param tokenWeiPerBytes The new rate to set.
	 */
	function setTokenWeiPerBytes(uint256 tokenWeiPerBytes) external {
		_tokenWeiPerBytes = tokenWeiPerBytes;
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
