// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; // Specify the compiler version

interface IZkTlsManager { 

  event SetTokenWeiPerBytes(uint256 tokenWeiPerBytes); 
  error UnInitializedBeacon();
  error InvalidGatewayId(uint8 gatewayId);
  error InvalidGatewayAddress(address gateway);

	function checkAccess(address account, address gateway) external view returns (bool);
}