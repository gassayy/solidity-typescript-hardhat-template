// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract AccountBeacon is UpgradeableBeacon {
    constructor(address initialImplementation, address admin) UpgradeableBeacon(initialImplementation, admin) {}
}