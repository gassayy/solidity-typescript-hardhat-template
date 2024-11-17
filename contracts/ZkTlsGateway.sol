// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { ISP1Verifier } from "./interfaces/ISP1Verifier.sol";

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
	address public manager;
	address public paymentToken;
	// @dev mapping of requestId to callbackInfo
	mapping(bytes32 => CallbackInfo) public requestCallbacks;
	// @dev mapping of prover id to prover info
	mapping(bytes32 => ProverInfo) public provers;

	function initialize(
		address manager_,
		address paymentToken_,
		address owner_
	) public initializer {
		__UUPSUpgradeable_init();
		__ReentrancyGuard_init();
		manager = manager_;
		paymentToken = paymentToken_;
		__Ownable_init(owner_);
	}

	function _authorizeUpgrade(
		address newImplementation
	) internal override onlyOwner {
		// TODO: add upgrade logic if needed
	}

	function setProver(bytes32 proverId, address verifierAddress_, bytes32 programVKey_) external onlyOwner {
		provers[proverId] = ProverInfo({
			verifierAddress: verifierAddress_,
			programVKey: programVKey_
		});
	}
	
	function estimateFee(
		uint256 requestBytes,
		uint256 maxResponseBytes
	) external view returns (uint256) {
		return (requestBytes + maxResponseBytes) * IZkTlsManager(manager).tokenWeiPerBytes();
	}

	function _generateRequestId(
		address account,
		uint256 nonce
	) internal view returns (bytes32) {
		return keccak256(abi.encodePacked(address(this), account, nonce));
	}

	function _populateCallbackInfo(
		bytes32 proverId,
		bytes32 requestHash,
		bytes32 requestTemplateHash,
		bytes32 responseTemplateHash,
		uint256 requestBytes,
		uint256 fee,
		uint64 nonce,
		uint256 maxResponseBytes
	) internal view returns (CallbackInfo memory cb) {
		cb = CallbackInfo({
			proverId: proverId,
			proxyAccount: msg.sender,
			requestBytes: requestBytes,
			maxResponseBytes: maxResponseBytes,
			nonce: nonce,
			fee: fee,
			requestHash: requestHash,
			requestTemplateHash: requestTemplateHash,
			responseTemplateHash: responseTemplateHash
		});
	}

	function requestTLSCallTemplate(
		bytes32 proverId,
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bool enableEncryption,
		IZkTlsAccount.TemplatedRequest calldata request,
		uint256 fee,
		uint64 nonce,
		uint256 maxResponseBytes
	) public payable returns (bytes32 requestId) {
		if (!IZkTlsManager(manager).hasAccess(msg.sender)) {
			revert UnauthorizedAccess();
		}

		requestId = _generateRequestId(msg.sender, nonce);

		if (request.fields.length != request.values.length) {
			revert FieldValueLengthMismatch();
		}

		bytes32 requestHash = keccak256(
			abi.encode(
				remote,
				serverName,
				encryptedKey,
				request.requestTemplateHash,
				request.fields,
				request.values
			)
		);

		requestCallbacks[requestId] = _populateCallbackInfo(
			proverId,
			requestHash,
			request.requestTemplateHash,
			request.responseTemplateHash,
			0, // init requestBytes
			fee,
			nonce,
			maxResponseBytes
		);

		emit RequestTLSCallBegin(
			requestId,
			proverId,
			request.requestTemplateHash,
			request.responseTemplateHash,
			remote,
			serverName,
			encryptedKey,
			maxResponseBytes
		);

		for (uint256 i = 0; i < request.fields.length; i++) {
			requestCallbacks[requestId].requestBytes += request
				.values[i]
				.length;
			emit RequestTLSCallTemplateField(
				requestId,
				request.fields[i],
				request.values[i],
				enableEncryption
			);
		}
		
	}

	function deliveryResponse(
		bytes32 requestId,
		bytes32 requestHash,
		bytes calldata response,
		bytes calldata proofs
	) public payable nonReentrant {
		CallbackInfo memory cb = requestCallbacks[requestId];

		// Use the custom error instead of require
		if (response.length > cb.maxResponseBytes) {
			revert ResponseExceedsMaxSize();
		}
		if (provers[cb.proverId].verifierAddress == address(0)) {
			revert InvalidProver();
		}
		// check if requestHash is valid
		if (cb.requestHash != requestHash) revert InvalidRequestHash();
		// calculate actual used bytes
		uint256 actualUsedBytes = response.length + cb.requestBytes;
		// encode the public values and call the verifier
		bytes memory publicValues = abi.encodePacked(requestHash, response);
		
		ISP1Verifier(provers[cb.proverId].verifierAddress).verifyProof(
			provers[cb.proverId].programVKey,
			publicValues, // public values is not used for mock verifier
			proofs // mock proof has to be 0 bytes
		);
		// execute the callback function
		bytes memory data = abi.encodeWithSignature(
			"deliveryResponse(bytes32,bytes32,bytes,uint256,uint256)",
			requestId,
			requestHash,
			response,
			cb.fee,
			actualUsedBytes
		);
		Address.functionCall(cb.proxyAccount, data);
		delete requestCallbacks[requestId];
	}
}
