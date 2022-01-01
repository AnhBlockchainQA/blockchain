// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

interface IStudService {
    function removeFromStud(uint256 _id) external;

    function setBaseFee(uint256 _baseFee) external;

    function getQueryPrice() external returns (uint256);

    function getHorsesInStud() external view returns (uint256[] memory);

    function getStudTime(uint256 _id) external view returns (uint256);

    function isHorseInStud(uint256 _id) external view returns (bool);

    function getMatingPrice(uint256 _id) external view returns (uint256);

    function getMinimumBreedPrice(uint256 _id) external view returns (uint256);

    function getStudInfo(uint256 _id)
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256
        );

    function putInStud(
        uint256 _id,
        uint256 _matingPrice,
        uint256 _duration
    ) external payable;
}
