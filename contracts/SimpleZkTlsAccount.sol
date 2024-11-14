// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IZkTlsAccount } from "./interfaces/IZkTlsAccount.sol";
import { IZkTlsGateway } from "./interfaces/IZkTlsGateway.sol";
import { ZkTlsManager } from "./ZkTlsManager.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import { IZkTlsResponseHandler } from "./interfaces/IZkTlsResponseHandler.sol";

import "hardhat/console.sol";

contract SimpleZkTlsAccount is IZkTlsAccount, Initializable {
	address public manager;
	address public gateway;
	address public responseHandler;
	address public paymentToken;
	address public refundAddress;
	uint64 public nonce;
	uint256 public lockedAmount;
	// used for upgrad
	uint8 public constant VERSION = 1;

	function initialize(
		address manager_,
		address gateway_,
		address paymentToken_,
		address responseHandler_,
		address refundAddress_
	) public initializer {
		manager = manager_;
		gateway = gateway_;
		paymentToken = paymentToken_;
		responseHandler = responseHandler_;
		refundAddress = refundAddress_;
		nonce = 0;
	}

	function requestTLSCall(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		bytes[] calldata data,
		uint256 fee,
		uint256 maxResponseBytes
	) external payable returns (bytes32 requestId) {
		// check payment token balance and gas
		_lockFee(fee);
		if (_estimateCallbackGas(maxResponseBytes) > msg.value)
			revert InsufficientPaidGas();
		// send request to gateway
		requestId = IZkTlsGateway(gateway).requestTLSCall(
			remote,
			serverName,
			encryptedKey,
			data,
			fee,
			maxResponseBytes,
			nonce
		);

		nonce++;
	}

	function requestTLSCallTemplate(
		string calldata remote,
		string calldata serverName,
		bytes calldata encryptedKey,
		TemplatedRequest calldata request,
		uint256 fee,
		uint256 maxResponseBytes
	) public payable returns (bytes32 requestId) {	
		// check payment token balance and gas
		_lockFee(fee);
		if (_estimateCallbackGas(maxResponseBytes) > msg.value)
			revert InsufficientPaidGas();
		// send request to gateway
		requestId = IZkTlsGateway(gateway).requestTLSCallTemplate(
			remote,
			serverName,
			encryptedKey,
			request,
			fee,
			nonce,
			maxResponseBytes
		);

		nonce++;
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
		if (msg.sender != gateway) revert UnauthorizedCaller();

		uint256 start = gasleft();
		bytes memory data = abi.encodeWithSelector(
			IZkTlsResponseHandler.handleResponse.selector,
			requestId,
			requestHash,
			response
		);
		Address.functionCall(responseHandler, data);
		uint256 usedGas = start - gasleft();
		uint256 paidFee = _transferFee(paidGas, usedGas, actualUsedBytes);
		emit PaymentInfo(paidGas, usedGas, fee, paidFee);
	}

	function _transferFee(
		uint256 paidGas,
		uint256 usedGas,
		uint256 actualUsedBytes
	) internal returns (uint256 paidFee) {
		if (paidGas < usedGas) revert InsufficientPaidGas();

		paidFee =
			actualUsedBytes *
			IZkTlsGateway(gateway).getTokenWeiPerBytes();
		// transfer fee to gateway
		SafeERC20.safeTransfer(IERC20(paymentToken), gateway, paidFee);

		// refund unused gas
		if (usedGas <= paidGas) {
			(bool sent, ) = gateway.call{ value: paidGas - usedGas }("");
			if (!sent) revert GasRefundFailed();
		}
	}

	function _lockFee(uint256 fee) internal {
		if (IERC20(paymentToken).balanceOf(address(this)) - lockedAmount < fee)
			revert InsufficientTokenBalance();
		lockedAmount += fee;
	}

	function _estimateCallbackGas(
		uint256 maxResponseBytes
	) internal view returns (uint256) {
		return
			ZkTlsManager(manager).callbackBaseGas() +
			maxResponseBytes * ZkTlsManager(manager).CALLBACK_UNIT_GAS();
	}

}
