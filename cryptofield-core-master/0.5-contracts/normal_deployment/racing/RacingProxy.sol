pragma solidity ^0.5.8;

import "./proxy/UpgradeabilityProxy.sol";
import "./proxy/BaseAdminUpgradeabilityProxy.sol";

/**
 * @title RacingProxy
 * @dev Extends from BaseAdminUpgradeabilityProxy with a constructor for
 * initializing the implementation, admin, and init data.
 */
contract RacingProxy is BaseAdminUpgradeabilityProxy, UpgradeabilityProxy {
	/**
	 * Contract constructor.
	 * @param _logic address of the initial implementation.
	 * @param _admin Address of the proxy administrator.
	 */
	constructor(address _logic, address _admin) UpgradeabilityProxy(_logic) public payable {
		assert(ADMIN_SLOT == keccak256("org.zeppelinos.proxy.admin"));
		_setProxyAdmin(_admin);
	}
}