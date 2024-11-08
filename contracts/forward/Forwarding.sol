// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IForwarding } from "../interfaces/IForwarding.sol";

import { console } from "hardhat/console.sol";

contract Forwarding is IForwarding {
    mapping(address => uint256) public nonces;
    
    function execute(
        ForwardRequest calldata req,
        bytes calldata signature
    ) external payable returns (bool, bytes memory) {
        if (!verify(req, signature)) revert InvalidSignature();
        if (nonces[req.from]++ != req.nonce) revert InvalidNonce();
        
        (bool success, bytes memory returnData) = req.to.call{
            gas: req.gas,
            value: req.value
        }(req.data);
        
        // Forward revert reason if call failed
        if (!success) {
            revert(string(returnData));
        }
        
        return (success, returnData);
    }
    
    function verify(
        ForwardRequest calldata req,
        bytes calldata signature
    ) public pure returns (bool) {
        bytes memory encodedData = abi.encode(
            req.from,
            req.to,
            req.value,
            req.gas,
            req.nonce,
            req.data
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(encodedData)));
        address recovered = ecrecover(
            digest,
            uint8(signature[0]),
            bytes32(signature[1:33]),
            bytes32(signature[33:65])
        );
        
        return recovered == req.from;
    }
}