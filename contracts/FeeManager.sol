// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IFeeManager } from "./interfaces/IFeeManager.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeeManager is IFeeManager, Ownable {
    uint256 private bytesPerToken; 
    address private paymentToken;

    // Constructor to initialize the fee percentage
    constructor(address _paymentToken, uint256 _bytesPerToken, address _owner) Ownable(_owner) {
        bytesPerToken = _bytesPerToken;
        paymentToken = _paymentToken;
    }

    // Set the bytes per token fee rate
    function setBytesPerToken(uint256 _bytesPerToken) external onlyOwner {
        bytesPerToken = _bytesPerToken;
    }

    // Get the current bytes per token fee rate
    function getBytesPerToken() external view returns (uint256) {
        return bytesPerToken;
    }

    // Set the payment token address
    function setPaymentToken(address _paymentToken) external onlyOwner {
        paymentToken = _paymentToken;
    }

    // Get the current payment token address
    function getPaymentToken() external view returns (address) {
        return paymentToken;
    }

    // Estimate the fee based on bytes used
    function estimateFee(uint256 requestBytes, uint256 maxResponseBytes) external view returns (uint256) {
        return (requestBytes + maxResponseBytes) / bytesPerToken;
    }

    // Claim collected fees (placeholder for actual implementation)
    function claimFee(uint256 amount, address recipient) external onlyOwner {
        if (amount <= 0) revert InvalidAmount();
        if (recipient == address(0)) revert InvalidRecipient();

        // Use custom error instead of require statement
        if (IERC20(paymentToken).balanceOf(address(this)) < amount) 
            revert InsufficientBalance();

        IERC20(paymentToken).transfer(recipient, amount);
        emit FeeClaimed(recipient, amount); 
    }

    // Transfer payment token to a specified address
    function transferPaymentToken(address from, address to, uint256 amount) external onlyOwner {
        if (amount <= 0) revert InvalidAmount();
        if (to == address(0)) 
            revert InvalidRecipient();

        // Check if the contract has enough balance
      if (IERC20(paymentToken).balanceOf(from) < amount) 
            revert InsufficientBalance();

        IERC20(paymentToken).transferFrom(from, to, amount);
        emit FeeTransferred(from, to, amount);
    }

}
