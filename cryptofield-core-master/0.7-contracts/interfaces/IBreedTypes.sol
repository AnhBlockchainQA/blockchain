// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

interface IBreedTypes {
    function getBreedType(uint256 _id) external view returns (bytes32);

    function generateBreedType(
        uint256 _id,
        uint256 _father,
        uint256 _mother
    ) external;

    function setBreedType(uint256 _id, bytes32 _breedType) external;
}
