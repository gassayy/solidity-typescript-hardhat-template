// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; // Specify the compiler version

interface IZkTlsManager { 

  event SetTokenWeiPerBytes(uint256 tokenWeiPerBytes);
  error InvalidAccessToProver();


  function checkAccess(address account) external view returns (bool);
  function getTokenWeiPerBytes() external view returns (uint256);

  function setAccountToGateway(address account, address gateway) external;
  function setTokenWeiPerBytes(uint256 tokenWeiPerBytes) external;
}