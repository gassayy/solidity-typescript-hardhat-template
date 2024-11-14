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

	uint256 public callbackBaseGas;
	uint256 public constant CALLBACK_UNIT_GAS = 4; // 4 gas per byte
	// gateway id to gateway address
	mapping(uint8 => address) public gatewayIdToGateway;
	// zktls account proxy address to gateway address
	mapping(address => address) public accountToGateway;
	uint256 public tokenWeiPerBytes;
	address public paymentToken;
	address public accountBeacon;
	// default payment receiver address
	address public defaultPaymentReceiver;
	address public defaultProxyAccount;

	/**
	 * @notice Initializes the contract with the specified payment token and owner.
	 * @dev This function can only be called once due to the `initializer` modifier.
	 * @param paymentToken_ The address of the ERC20 token used for payments.
	 * @param owner_ The address that will be set as the owner of the contract.
	 */
	function initialize(
		address paymentToken_,
		address owner_
	) public initializer {
		__UUPSUpgradeable_init();
		__Ownable_init(owner_);
		paymentToken = paymentToken_;
		accountBeacon = address(0);
	}

	/**
	 * @notice Internally links an account proxy to a gateway address.
	 * @dev This function updates the `accountToGateway` mapping.
	 * @param accountProxy The address of the account proxy to be linked.
	 * @param gateway The gateway address to associate with the account proxy.
	 */
	function _setAccountToGateway(
		address accountProxy,
		address gateway
	) internal {
		accountToGateway[accountProxy] = gateway;
	}

	/**
	 * @notice Checks if a specific account is associated with a given gateway.
	 * @param account The address of the account to verify.
	 * @param gateway The gateway address to check against the account.
	 * @return bool Returns true if the account is linked to the specified gateway, false otherwise.
	 */
	function checkAccess(
		address account,
		address gateway
	) external view returns (bool) {
		return accountToGateway[account] == gateway;
	}

	/**
	 * @notice Sets the address of the account beacon.
	 * @dev This function can only be called by the contract owner.
	 * @param accountBeacon_ The new address of the account beacon.
	 */
	function setAccountBeacon(address accountBeacon_) external onlyOwner {
		accountBeacon = accountBeacon_;
	}

	/**
	 * @notice Updates the gateway address for a specific gateway ID.
	 * @dev This function can only be called by the contract owner.
	 * @param gatewayId The ID of the gateway to update.
	 * @param gatewayAddress The new address to associate with the gateway ID.
	 */
	function setGateway(
		uint8 gatewayId,
		address gatewayAddress
	) external onlyOwner {
		gatewayIdToGateway[gatewayId] = gatewayAddress;
	}

	/**
	 * @notice Authorizes an account to be linked to a specific gateway.
	 * @dev This function can only be called by the contract owner.
	 * @param account The address of the account to authorize.
	 * @param gateway The gateway address to associate with the account.
	 */
	function authorizeAccount(
		address account,
		address gateway
	) external onlyOwner {
		accountToGateway[account] = gateway;
	}
	
	/**
	 * @notice Authorizes an upgrade to a new contract implementation.
	 * @dev Emits an `UpgradeAuthorized` event upon successful authorization.
	 * @param newImplementation The address of the new contract implementation.
	 */
	function _authorizeUpgrade(
		address newImplementation
	) internal override onlyOwner {
		emit UpgradeAuthorized(newImplementation);
	}

	/**
	 * @notice Creates a new account and links it to the specified gateway and response handler.
	 * @dev Reverts if the account beacon is uninitialized or the gateway ID is invalid.
	 * @param gatewayId The ID of the gateway for which the account is created.
	 * @param responseHandler The address to handle responses for the account.
	 * @param refundAddress The address to receive refunds.
	 * @return account The address of the newly created account proxy.
	 */
	function createAccount(
		uint8 gatewayId,
		address responseHandler,
		address refundAddress
	) external returns (address account) {
		if (accountBeacon == address(0)) revert UnInitializedBeacon();
		if (gatewayIdToGateway[gatewayId] == address(0))
			revert InvalidGatewayId(gatewayId);

		bytes memory data = abi.encodeCall(
			SimpleZkTlsAccount.initialize,
			(
				address(this),
				gatewayIdToGateway[gatewayId],
				paymentToken,
				responseHandler,
				refundAddress
			)
		);
		BeaconProxy beaconProxy = new BeaconProxy(accountBeacon, data);
		_setAccountToGateway(
			address(beaconProxy),
			gatewayIdToGateway[gatewayId]
		);
		emit SimpleZkTlsAccountCreated(
			gatewayId,
			gatewayIdToGateway[gatewayId],
			address(beaconProxy)
		);
		return address(beaconProxy);
	}
}
