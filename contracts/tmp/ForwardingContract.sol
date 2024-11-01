// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ForwardingContract {
    struct ForwardRequest {
        address from;      // Original signer
        address to;        // Target contract
        uint256 value;     // ETH value to forward
        uint256 gas;       // Gas limit
        uint256 nonce;     // Unique nonce
        bytes data;        // Call data
    }
    
    mapping(address => uint256) public nonces;
    
    function execute(
        ForwardRequest calldata req,
        bytes calldata signature
    ) external payable returns (bool, bytes memory) {
        require(verify(req, signature), "Invalid signature");
        require(nonces[req.from]++ == req.nonce, "Invalid nonce");
        
        (bool success, bytes memory returndata) = req.to.call{
            gas: req.gas,
            value: req.value
        }(abi.encodePacked(req.data, req.from));
        
        // Forward revert reason if call failed
        if (!success) {
            assembly {
                revert(add(returndata, 32), mload(returndata))
            }
        }
        
        return (success, returndata);
    }
    
    function verify(
        ForwardRequest calldata req,
        bytes calldata signature
    ) public pure returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(abi.encode(
                req.from,
                req.to,
                req.value,
                req.gas,
                req.nonce,
                req.data
            ))
        ));
        
        // Recover the signer address
        address recovered = ecrecover(
            digest,
            uint8(signature[0]),
            bytes32(signature[1:33]),
            bytes32(signature[33:65])
        );
        
        return recovered == req.from;
    }
}