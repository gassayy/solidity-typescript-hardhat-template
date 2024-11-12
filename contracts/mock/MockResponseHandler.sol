// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IZkTlsResponseHandler } from "../interfaces/IZkTlsResponseHandler.sol";

contract MockResponseHandler is IZkTlsResponseHandler {
  
  event ResponseHandled(bytes32 requestId, bytes32 requestHash, bytes response);
  
  constructor() { }
  function handleResponse(bytes32 requestId, bytes32 requestHash, bytes calldata response) external {
    emit ResponseHandled(requestId, requestHash, response);
  }
}
