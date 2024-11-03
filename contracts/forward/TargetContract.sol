// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TargetContract {
    mapping(address => uint256) public values;
    
    function setValue(uint256 _value) external {
        // Store value for the real sender, not the forwarder
        values[msg.sender] = _value;
    }
    
    function getValue(address user) external view returns (uint256) {
        return values[user];
    }
}