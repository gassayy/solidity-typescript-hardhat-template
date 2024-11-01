// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IERC677Receiver {
    function onTokenTransfer(address _sender, uint _value, bytes memory _data) external returns (bool);
}

contract PaymentToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        // Initialize your token here
    }

    /**
     * @dev transfer token to a contract address with additional data if the recipient is a contract.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     * @param _data The extra data to be passed to the receiving contract.
     */
    function transferAndCall(address _to, uint _value, bytes memory _data) public returns (bool) {
        require(_to != address(0), "ERC677: transfer to zero address");
        
        bool transferred = transfer(_to, _value);
        if (transferred) {
            _callOnTokenTransfer(msg.sender, _to, _value, _data);
        }
        return transferred;
    }

    /**
     * @dev Calls onTokenTransfer method if the target is a contract
     */
    function _callOnTokenTransfer(address _from, address _to, uint _value, bytes memory _data) private {
        uint256 codeLength;
        assembly {
            codeLength := extcodesize(_to)
        }
        
        if (codeLength > 0) {
            try IERC677Receiver(_to).onTokenTransfer(_from, _value, _data) returns (bool success) {
                require(success, "ERC677: onTokenTransfer failed");
            } catch {
                revert("ERC677: failed to call onTokenTransfer");
            }
        }
    }
}
