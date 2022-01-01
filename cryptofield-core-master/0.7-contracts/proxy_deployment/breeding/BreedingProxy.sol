// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

/**
 * @title BreedingProxy
 * @dev Extends from BaseAdminUpgradeabilityProxy with a constructor for
 * initializing the implementation, admin, and init data.
 */
contract BreedingProxy is TransparentUpgradeableProxy {
	/**
	 * Contract constructor.
	 * @param _logic address of the initial implementation.
	 * @param _admin Address of the proxy administrator.
	 */
	constructor(address _logic, address _admin) TransparentUpgradeableProxy(_logic, _admin, "") payable {}
}
