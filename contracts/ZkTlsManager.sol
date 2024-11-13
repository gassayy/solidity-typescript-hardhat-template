// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { BeaconProxy } from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import { IZkTlsManager } from "./interfaces/IZkTlsManager.sol";
import { SimpleZkTlsAccount } from "./SimpleZkTlsAccount.sol";


contract ZkTlsManager is
	IZkTlsManager,
	Initializable,
	UUPSUpgradeable,
	OwnableUpgradeable
{
	event UpgradeAuthorized(address indexed newImplementation);

	event SimpleZkTlsAccountCreated(
		uint8 indexed gatewayId,
		address indexed gateway,
		address beaconProxy
	);

	// gateway id to gateway address
	mapping(uint8 => address) private _gatewayIdToGateway;
	// zktls account proxy address to gateway address
	mapping(address => address) private _accountToGateway;
	uint256 private _tokenWeiPerBytes;
	address private _paymentToken;
	address private _accountBeacon;
	address private _accountBeaconAdmin;

	// constructor() {
	//   _disableInitializers();
	// }

	/**
	 * @notice Initializes the contract with a specified token rate and owner.
	 * @param paymentToken The address of the payment token.
	 * @param accountBeaconAdmin The address of the account beacon admin.
	 * @param owner The address of the initial owner of the contract.
	 */
	function initialize(
		address paymentToken,
		address accountBeaconAdmin,
		address owner
	) public initializer {
		__UUPSUpgradeable_init();
		_paymentToken = paymentToken;
		_accountBeacon = address(0);
		_accountBeaconAdmin = accountBeaconAdmin;
		__Ownable_init(owner);
	}

	/**
	 * @notice Authorizes an upgrade to a new contract implementation.
	 * @param newImplementation The address of the new contract implementation.
	 */
	function _authorizeUpgrade(
		address newImplementation
	) internal override onlyOwner {
		emit UpgradeAuthorized(newImplementation);
	}

	/**
	 * @notice Verifies if a specific account is linked to a given gateway.
	 * @param account The address of the account to verify.
	 * @param gateway The address of the gateway to check against the account.
	 * @return bool Returns true if the account is linked to the specified gateway, false otherwise.
	 */
	function checkAccess(
		address account,
		address gateway
	) external view returns (bool) {
		return _accountToGateway[account] == gateway;
	}

	function setAccountBeacon(address accountBeacon) external onlyOwner {
		_accountBeacon = accountBeacon;
	}

	function getAccountBeacon() external view returns (address) {
		return _accountBeacon;
	}

	/**
	 * @notice Links a specific account proxy to a gateway address.
	 * @param accountProxy The address of the account proxy to link.
	 * @param gateway The gateway address to link to the account proxy.
	 */
	function _setAccountToGateway(address accountProxy, address gateway) internal {
		_accountToGateway[accountProxy] = gateway;
	}

	/**
	 * @notice Retrieves the gateway address associated with a specific gateway ID.
	 * @param gatewayId The ID of the gateway to retrieve.
	 * @return address The address of the gateway associated with the given ID.
	 */
	function getGateway(uint8 gatewayId) external view returns (address) {
		return _gatewayIdToGateway[gatewayId];
	}

	/**
	 * @notice Sets the gateway address for a specific gateway ID.
	 * @param gatewayId The ID of the gateway to update.
	 * @param gatewayAddress The new address to associate with the gateway ID.
	 */
	function setGateway(
		uint8 gatewayId,
		address gatewayAddress
	) external onlyOwner {
		_gatewayIdToGateway[gatewayId] = gatewayAddress;
	}

	/**
	 * @notice Creates a new account and links it to the given account owner and response handler.
	 * @param gatewayId The ID of the gateway to create the account for.
	 * @param responseHandler The response handler address to link to the account.
	 */
	function createAccount(
		uint8 gatewayId,
		address responseHandler
	) external returns (address account) {
		if (_accountBeacon == address(0)) revert UnInitializedBeacon();
		if (_gatewayIdToGateway[gatewayId] == address(0))
			revert InvalidGatewayId(gatewayId);

		bytes memory data = abi.encodeCall(
			SimpleZkTlsAccount.initialize,
			(_gatewayIdToGateway[gatewayId], _paymentToken, responseHandler)
		);
		BeaconProxy beaconProxy = new BeaconProxy(_accountBeacon, data);
		_setAccountToGateway(address(beaconProxy), _gatewayIdToGateway[gatewayId]);
		emit SimpleZkTlsAccountCreated(
			gatewayId,
			_gatewayIdToGateway[gatewayId],
			address(beaconProxy)
		);
		return address(beaconProxy);
	}
}
