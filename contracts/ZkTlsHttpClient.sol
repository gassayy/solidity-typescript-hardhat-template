// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IZkTLSGateway } from "./interfaces/IZkTLSGateway.sol";

abstract contract ZkTlsHttpClient {

  IZkTLSGateway private _gateway;
  address private immutable _gatewayAddress;

  constructor(address gateway) {
    _gateway = IZkTLSGateway(gateway);
    _gatewayAddress = gateway;
  }

  function get(uint64 max_response_bytes, string calldata remote, string calldata serverName, bytes calldata encrypted_key, bytes[] calldata data) public returns (bytes32 requestId){
    return _gateway.requestTLSCall(max_response_bytes, remote, serverName, encrypted_key, data);
  }

  function post(uint64 max_response_bytes, string calldata remote, string calldata serverName, bytes calldata encrypted_key, bytes[] calldata data) public returns (bytes32 requestId) {
    return _gateway.requestTLSCall(max_response_bytes, remote, serverName, encrypted_key, data);
  }

  /**
   * @dev This function is called by the gateway when a response is received.
   */
  function deliveryResponse(bytes32 requestId, bytes[] calldata response) internal virtual;

  function _deliveryResponse(bytes32 requestId, bytes[] calldata response) internal {
    if (msg.sender != _gatewayAddress) {
      revert("ZkTlsHttpClient: only gateway can deliver response");
    }

    deliveryResponse(requestId, response);
  }

}
