// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

interface IBreeding {
    function setCore(address _core) external;

    function changePercentageAllocations() external;

    function setBreedTypesAddress(address _breedTypes) external;

    function setStudServiceAddress(address _studService) external;

    function getParents(uint256 _horseId) external view returns (uint256[2] memory);

    function mix(
        uint256 _maleId,
        uint256 _femaleId,
        bytes32 _color
    ) external payable;

    function getHorseOffspringStats(uint256 _horseId) external view returns (uint256);

    function getHorseSex(uint256 _horseId) external view returns (bytes32);

    function isGrandparent(uint256 _horseId, uint256 _grandparentId) external view returns (bool);

    function areHorsesRelated(uint256 _male, uint256 _female) external view returns (bool, string memory);

    function breedingData(uint256 _id)
        external
        view
        returns (
            uint256[2] memory,
            uint256[] memory,
            uint256
        );
}
