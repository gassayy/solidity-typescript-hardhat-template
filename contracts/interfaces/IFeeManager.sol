// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFeeManager {

    event FeePerByteUpdated(uint256 feePerByte);
    event PaymentTokenUpdated(address token);
    event FeeTransferred(address from, address to, uint256 amount);
    event FeeClaimed(address recipient, uint256 amount);

    error InvalidPaymentToken();
    error InvalidFeePerByte();
    error InsufficientBalance();
    error InvalidAmount();
    error InvalidRecipient();

    function getBytesPerToken() external view returns (uint256);
    function setBytesPerToken(uint256 numBytes) external;

    function setPaymentToken(address token) external;
    function getPaymentToken() external view returns (address);

    function estimateFee(uint256 requestBytes, uint256 maxResponseBytes) external view returns (uint256);
    function claimFee(uint256 amount, address recipient) external;

    function transferPaymentToken(address from, address to, uint256 amount) external;
}
