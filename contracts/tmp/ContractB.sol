// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ContractB {
    IERC20 public paymentToken;

    constructor(IERC20 _paymentToken) {
        paymentToken = _paymentToken;
    }

    function bar(uint256 amount, address clientAddress) external {
        uint256 balance = paymentToken.balanceOf(clientAddress);

        // Check allowance
        uint256 allowed = paymentToken.allowance(clientAddress, address(this));
        require(allowed >= amount, "ContractB is not allowed to transfer enough tokens");

        require(balance >= amount, "Insufficient balance in ContractA");
        // Transfer tokens from ContractA to ContractB
        bool success = paymentToken.transferFrom(clientAddress, address(this), amount);
        require(success, "Token transfer failed");
    }
} 