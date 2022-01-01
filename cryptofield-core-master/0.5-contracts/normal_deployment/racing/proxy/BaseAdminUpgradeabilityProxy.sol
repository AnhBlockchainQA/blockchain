pragma solidity ^0.5.8;

import "./BaseUpgradeabilityProxy.sol";

/**
 * @title BaseAdminUpgradeabilityProxy
 * @dev This contract combines an upgradeability proxy with an authorization
 * mechanism for administrative tasks.
 * All external functions in this contract must be guarded by the
 * `ifProxyAdmin` modifier. See ethereum/solidity#3864 for a Solidity
 * feature proposal that would enable this to be done automatically.
 */
contract BaseAdminUpgradeabilityProxy is BaseUpgradeabilityProxy {
	/**
	 * @dev Emitted when the administration has been transferred.
	 * @param previousAdmin Address of the previous admin.
	 * @param newProxyAdmin Address of the new admin.
	 */
	event ProxyAdminChanged(address previousAdmin, address newProxyAdmin);

	/**
	 * @dev Storage slot with the admin of the contract.
	 * This is the keccak-256 hash of "org.zeppelinos.proxy.admin", and is
	 * validated in the constructor.
	 */
  	bytes32 internal constant ADMIN_SLOT = 0x10d6a54a4754c8869d6886b5f5d7fbfa5b4522237ea5c60d11bc4e7a1ff9390b;

  	/**
	 * @dev Modifier to check whether the `msg.sender` is the admin.
	 * If it is, it will run the function. Otherwise, it will delegate the call
	 * to the implementation.
	 */
	modifier ifProxyAdmin() {
		if (msg.sender == _proxyAdmin()) {
		    _;
		} else {
		    _fallback();
		}
	}

	/**
	 * @return The address of the proxy admin.
	 */
	function proxyAdmin() external view returns (address) {
		return _proxyAdmin();
	}

	/**
	 * @return The version of logic contract
	 */
	function proxyVersion() external view returns (string memory) {
		return _version;
	}

	/**
	 * @return The address of the implementation.
	 */
	function proxyImplementation() external view returns (address) {
		return _implementation();
	}

	/**
	 * @dev Changes the admin of the proxy.
	 * Only the current admin can call this function.
	 * @param newProxyAdmin Address to transfer proxy administration to.
	 */
	function changeProxyAdmin(address newProxyAdmin) external ifProxyAdmin {
		require(newProxyAdmin != address(0), "Cannot change the admin of a proxy to the zero address");
		emit ProxyAdminChanged(_proxyAdmin(), newProxyAdmin);
		_setProxyAdmin(newProxyAdmin);
	}

	/**
	 * @dev Upgrade the backing implementation of the proxy.
	 * Only the admin can call this function.
	 * @param newImplementation Address of the new implementation.
	 * @param newVersion of proxied contract.
	 */
	function upgradeProxyTo(address newImplementation, string calldata newVersion) external ifProxyAdmin {
		_upgradeProxyTo(newImplementation, newVersion);
	}

	/**
	 * @dev Upgrade the backing implementation of the proxy and call a function
	 * on the new implementation.
	 * This is useful to initialize the proxied contract.
	 * @param newImplementation Address of the new implementation.
	 * @param newVersion of proxied contract.
	 * @param data Data to send as msg.data in the low level call.
	 * It should include the signature and the parameters of the function to be called, as described in
	 * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
	 */
	function upgradeProxyToAndCall(address newImplementation, string calldata newVersion, bytes calldata data) payable external ifProxyAdmin {
		_upgradeProxyTo(newImplementation, newVersion);
		(bool success,) = newImplementation.delegatecall(data);
		require(success);
	}

	/**
	 * @return The admin slot.
	 */
	function _proxyAdmin() internal view returns (address adm) {
		bytes32 slot = ADMIN_SLOT;
		assembly {
    		adm := sload(slot)
		}
	}

	/**
	 * @dev Sets the address of the proxy admin.
	 * @param newProxyAdmin Address of the new proxy admin.
	 */
	function _setProxyAdmin(address newProxyAdmin) internal {
		bytes32 slot = ADMIN_SLOT;

		assembly {
			sstore(slot, newProxyAdmin)
		}
	}

	/**
	 * @dev Only fall back when the sender is not the admin.
	 */
	function _willFallback() internal {
		require(msg.sender != _proxyAdmin(), "Cannot call fallback function from the proxy admin");
		super._willFallback();
	}
}