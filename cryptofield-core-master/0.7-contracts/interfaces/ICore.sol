// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

interface ICore {
    function tokenExists(uint256 _tokenId) external view returns (bool);

    function balanceOf(address _owner) external view returns (uint256);

    function ownerOf(uint256 _tokenId) external view returns (address);

    function approve(address _approved, uint256 _tokenId) external payable;

    function getApproved(uint256 _tokenId) external view returns (address);

    function setApprovalForAll(address _to, bool _approved) external;

    function getBaseValue(uint256 _horse) external view returns (uint256);

    // Moved into IHorseData
    // function getBloodline(uint256 _horse) external view returns (bytes32);

    // Removed
    // function setBaseValue(uint256 _horseId, uint256 _baseValue) external;

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;

    function isTokenApproved(address _spender, uint256 _tokenId) external view returns (bool);

    function mintCustomHorse(
        address _owner,
        uint256 _genotype,
        bytes32 _gender,
        bytes32 _name,
        bytes32 _color
    ) external;

    function mintOffspring(
        address _owner,
        uint256 _male,
        uint256 _female,
        bytes32 _color
    ) external;

    function getHorseData(uint256 _tokenId)
        external
        view
        returns (
            bytes32,
            uint256,
            uint256,
            uint256,
            bytes32,
            bytes32,
            bytes32,
            bytes32,
            address
        );

    function setHorseData(
        address _owner,
        uint256 _tokenId,
        bytes32 _sex,
        uint256 _baseValue,
        uint256 _timestamp,
        uint256 _genotype,
        bytes32 _bloodline,
        bytes32 _hType,
        bytes32 _name,
        bytes32 _color
    ) external;

    function nextTokenId() external view returns (uint256);
}
