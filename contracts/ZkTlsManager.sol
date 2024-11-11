// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IZkTlsManager } from "./interfaces/IZkTlsManager.sol";

contract ZkTlsManager is IZkTlsManager {
  
  // zktls account address to prover address
  mapping(address => address) private _accountToGateway;  
  uint256 private _tokenWeiPerBytes;

  /**
   * @notice Checks if the given account has access.
   * @param account The address of the account to check.
   * @return bool True if the account has access, false otherwise.
   */
	function checkAccess(address account) external view returns (bool) {
    return _accountToGateway[account] != address(0);
  }

  /**
   * @notice Sets the gateway address for a given account.
   * @param account The address of the account.
   * @param gateway The address of the gateway to associate with the account.
   */
  function setAccountToGateway(address account, address gateway) external {
    _accountToGateway[account] = gateway;
  }

  /**
   * @notice Retrieves the token wei per bytes value.
   * @return uint256 The current token wei per bytes value.
   */
	function getTokenWeiPerBytes() external view returns (uint256) {
    return _tokenWeiPerBytes;
  }

  /**
   * @notice Sets the token wei per bytes value.
   * @param tokenWeiPerBytes The new token wei per bytes value to set.
   */
  function setTokenWeiPerBytes(uint256 tokenWeiPerBytes) external {
    _tokenWeiPerBytes = tokenWeiPerBytes;
  }
}
