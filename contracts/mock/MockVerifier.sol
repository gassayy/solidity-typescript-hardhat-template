// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IZkTlsVerifier } from "../interfaces/IZkTlsVerifier.sol";

contract MockVerifier is IZkTlsVerifier {
  
  event ProofVerified(bytes requestHash, bytes proof);

  constructor() {
    // nothing to initialize
  }
  
  function verify(
    bytes calldata publicValues, // requestHash + responseData
    bytes calldata proof
  ) external returns (bool) {
    emit ProofVerified(publicValues, proof);
    return true;
  }
}
