// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IZkTLSGateway {
    
    event RequestTLSCallBegin(bytes32 indexed prover, string remote, string serverName, bytes encrypted_key, uint64 max_response_bytes);
    event RequestTLSCallSegment(bytes data, bool is_encrypted);

    function requestTLSCall(
        uint64 max_response_bytes,
        string calldata remote,
        string calldata serverName,
        bytes calldata encrypted_key,
        bytes[] calldata data
    ) external returns (bytes32 requestId);
}
