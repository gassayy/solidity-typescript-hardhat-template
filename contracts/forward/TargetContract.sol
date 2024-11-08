// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { console } from "hardhat/console.sol";


contract TargetContract {
    mapping(address => uint256) public values;
    
    function setValue(uint256 _value) external {
        // Store value for the real sender, not the forwarder
        values[msg.sender] = _value;
        console.log("targetContract - msg.sender", msg.sender);
        console.log("targetContract - Value set to", _value);
    }
    
    function getValue(address user) external view returns (uint256) {
        console.log("targetContract - get - user:", user);
        return values[user];
    }
}