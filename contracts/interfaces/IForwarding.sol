// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IForwarding {
    error InvalidSignature();
    error InvalidNonce();

    struct ForwardRequest {
        address from;      // Original signer
        address to;        // Target contract
        uint256 value;     // ETH value to forward
        uint256 gas;       // Gas limit
        uint256 nonce;     // Unique nonce
        bytes data;        // Call data
    }

    event DigestCreated(bytes32 digest);

    function execute(
        ForwardRequest calldata req,
        bytes calldata signature
    ) external payable returns (bool, bytes memory);

    function verify(
        ForwardRequest calldata req,
        bytes calldata signature
    ) external pure returns (bool);

    function nonces(address user) external view returns (uint256);
} 