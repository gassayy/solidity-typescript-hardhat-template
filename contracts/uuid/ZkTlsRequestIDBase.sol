// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ZkTlsRequestIDBase {
  
  function makeZkTlsInputSeed(
    address _requester,
    uint256 _nonce
  ) internal view  returns (uint256) {
    return uint256(keccak256(abi.encode(address(this), _requester, _nonce)));
  }

  function makeRequestId(bytes32 gatewayHash, uint256 _zkTlsInputSeed) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(gatewayHash, _zkTlsInputSeed));
  }
}