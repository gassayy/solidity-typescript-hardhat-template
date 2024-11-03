// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IZkTLSGateway} from "./interfaces/IZkTLSGateway.sol";
import {ZkTlsRequestIDBase} from "./uuid/ZkTlsRequestIDBase.sol";

abstract contract ZkTLSGateway is IZkTLSGateway, ZkTlsRequestIDBase {

  uint256 private _nonce;
  bytes32 private _gatewayHash = keccak256(abi.encode(address(this)));

	function requestTLSCall(
		uint64 max_response_bytes,
		string calldata remote,
		string calldata serverName,
		bytes calldata encrypted_key,
		bytes[] calldata data
	) public returns (bytes32 requestId) {

		uint256 zkTlsInputSeed = makeZkTlsInputSeed(msg.sender, _nonce);
		requestId = makeRequestId(_gatewayHash, zkTlsInputSeed);

		emit RequestTLSCallBegin(
			0x0,
			remote,
			serverName,
			encrypted_key,
      max_response_bytes
		);

		for (uint256 i = 0; i < data.length; i++) {
			bool is_encrypted = i % 2 == 0;
			emit RequestTLSCallSegment(data[i], !is_encrypted);
		}
    // post increment nonce
    _nonce++;
	}
}
