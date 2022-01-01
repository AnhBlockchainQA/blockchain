pragma solidity ^0.5.8;

import "./BaseUpgradeabilityProxy.sol";

/**
 * @title UpgradeabilityProxy
 * @dev Extends BaseUpgradeabilityProxy with a constructor for initializing
 * implementation and init data.
 */
contract UpgradeabilityProxy is BaseUpgradeabilityProxy {
	/**
	 * @dev Contract constructor.
	 * @param _logic Address of the initial implementation.
	 */
	constructor(address _logic) public payable {
		assert(IMPLEMENTATION_SLOT == keccak256("org.zeppelinos.proxy.implementation"));
		_setProxyImplementation(_logic, "1.0.0");
	}
}