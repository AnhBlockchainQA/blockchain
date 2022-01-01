// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

interface IHorseData {
    function getBloodlineFromParents(bytes32 _father, bytes32 _mother)
        external
        view
        returns (bytes32);

    function getBloodline(uint256 _batch) external pure returns (bytes32);

    function getGenotype(uint256 _batch) external pure returns (uint256);

    function getBaseValue(uint256 _batch) external pure returns (uint256);
}
