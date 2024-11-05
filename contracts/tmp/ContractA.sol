// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";


contract ContractA {
    IERC20 public paymentToken;
    address public contractB;

    constructor(IERC20 _paymentToken, address _b) {
        paymentToken = _paymentToken;
        contractB = _b;
    }

    function foo(uint256 amount) external payable {
        require(msg.value > 0, "Ether required");
        require(paymentToken.balanceOf(address(this)) >= amount, "Insufficient token balance");
        // Call ContractB's bar function
        paymentToken.approve(contractB, amount);
        (bool success, ) = contractB.call{value: 0}(
            abi.encodeWithSignature("bar(uint256,address)", amount, address(this))
        );
        require(success, "Call to ContractB failed");
    }
} 