pragma solidity ^0.5.8;

import "./Proxy.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title BaseUpgradeabilityProxy
 * @dev This contract implements a proxy that allows to change the
 * implementation address to which it will delegate.
 * Such a change is called an implementation upgrade.
 */
contract BaseUpgradeabilityProxy is Proxy {
	using Address for address;

	/**
	 * @dev The version of current(active) logic contract
	 */
    string internal _version;

	/**
	 * @dev Storage slot with the address of the current implementation.
	 * This is the keccak-256 hash of "org.zeppelinos.proxy.implementation", and is
	 * validated in the constructor.
	 */
	bytes32 internal constant IMPLEMENTATION_SLOT = 0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3;

	/**
	 * @dev Emitted when the implementation is upgraded.
	 * @param implementation Address of the new implementation.
	 */
	event Upgraded(address indexed implementation);

	/**
	 * @dev Returns the current implementation.
	 * @return Address of the current implementation
	 */
	function _implementation() internal view returns (address impl) {
		bytes32 slot = IMPLEMENTATION_SLOT;
		assembly {
		    impl := sload(slot)
		}
	}

	/**
	 * @dev Upgrades the proxy to a new implementation.
	 * @param newImplementation Address of the new implementation.
	 * @param newVersion of proxied contract.
	 */
	function _upgradeProxyTo(address newImplementation, string memory newVersion) internal {
		_setProxyImplementation(newImplementation, newVersion);

		emit Upgraded(newImplementation);
	}

	/**
	 * @dev Sets the implementation address of the proxy.
	 * @param newImplementation Address of the new implementation.
	 * @param newVersion of proxied contract.
	 */
	function _setProxyImplementation(address newImplementation, string memory newVersion) internal {
		require(newImplementation.isContract(), "Cannot set a proxy implementation to a non-contract address");

 		_version = newVersion;

		bytes32 slot = IMPLEMENTATION_SLOT;

		assembly {
		    sstore(slot, newImplementation)
		}
	}
}