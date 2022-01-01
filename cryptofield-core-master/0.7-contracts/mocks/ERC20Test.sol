// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Test is ERC20 {
    constructor(uint256 initialSupply) ERC20("WETH Test", "WETH") {
        _mint(msg.sender, initialSupply);
    }
}
