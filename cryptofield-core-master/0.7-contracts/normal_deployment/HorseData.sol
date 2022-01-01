// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";

/**
* @title HorseData
* @author The VHS team
*/
contract HorseData {
    using SafeMath for uint256;

    mapping(bytes32 => bytes32) internal bloodlines;

    constructor() {
        // Bloodline matrix.
        // Nakamoto - Szabo - Finney - Buterin
        bloodlines[keccak256(abi.encodePacked(bytes32("N"), bytes32("N")))] = "N";
        bloodlines[keccak256(abi.encodePacked(bytes32("N"), bytes32("S")))] = "S";
        bloodlines[keccak256(abi.encodePacked(bytes32("N"), bytes32("F")))] = "F";
        bloodlines[keccak256(abi.encodePacked(bytes32("N"), bytes32("B")))] = "B";
        bloodlines[keccak256(abi.encodePacked(bytes32("S"), bytes32("N")))] = "S";
        bloodlines[keccak256(abi.encodePacked(bytes32("S"), bytes32("S")))] = "S";
        bloodlines[keccak256(abi.encodePacked(bytes32("S"), bytes32("F")))] = "F";
        bloodlines[keccak256(abi.encodePacked(bytes32("S"), bytes32("B")))] = "B";
        bloodlines[keccak256(abi.encodePacked(bytes32("F"), bytes32("N")))] = "F";
        bloodlines[keccak256(abi.encodePacked(bytes32("F"), bytes32("S")))] = "F";
        bloodlines[keccak256(abi.encodePacked(bytes32("F"), bytes32("F")))] = "F";
        bloodlines[keccak256(abi.encodePacked(bytes32("F"), bytes32("B")))] = "B";
        bloodlines[keccak256(abi.encodePacked(bytes32("B"), bytes32("N")))] = "B";
        bloodlines[keccak256(abi.encodePacked(bytes32("B"), bytes32("S")))] = "B";
        bloodlines[keccak256(abi.encodePacked(bytes32("B"), bytes32("F")))] = "B";
        bloodlines[keccak256(abi.encodePacked(bytes32("B"), bytes32("B")))] = "B";
        bloodlines[keccak256(abi.encodePacked(bytes32("B"), bytes32("N")))] = "B";
    }

    /** @notice Returns a bloodline based in _batchNumber
      * @param _batchNumber number of the batch to identify the bloodline
      * @return bytes32 representing a bloodline
     */
    function getBloodline(uint256 _batchNumber) public pure returns(bytes32) {
        bytes32 bloodline;

        if(_batchNumber == 1) {
            bloodline = bytes32("N");
        } else if(_batchNumber == 2) {
            bloodline = bytes32("N");
        } else if(_batchNumber == 3) {
            bloodline = bytes32("S");
        } else if(_batchNumber == 4) {
            bloodline = bytes32("S");
        } else if(_batchNumber == 5) {
            bloodline = bytes32("F");
        } else if(_batchNumber == 6) {
            bloodline = bytes32("F");
        } else if(_batchNumber == 7) {
            bloodline = bytes32("F");
        } else if(_batchNumber == 8) {
            bloodline = bytes32("B");
        } else if(_batchNumber == 9) {
            bloodline = bytes32("B");
        } else {
            bloodline = bytes32("B");
        }

        return bloodline;
    }

    /** @notice Gets a genotype based in _batchNumber
      * @param _batchNumber Integer identifying the genotype
      * @return integer identifying the genotype
     */
    function getGenotype(uint256 _batchNumber) public pure returns(uint256) {
        require(_batchNumber >= 1 && _batchNumber <= 10, "Batch number out of bounds");
        return _batchNumber;
    }

    /** @notice Gets the base value of a horse based in _batchNumber
      * @param _batchNumber Integer identifying the genotype of the horse
      * @return integer representing the base value of the horse
     */
    function getBaseValue(uint256 _batchNumber) public view returns(uint256) {
        uint256 baseValue;

        if(_batchNumber == 1) {
            baseValue = _getRandom(4, 100);
        } else if(_batchNumber == 2) {
            baseValue = _getRandom(9, 90);
        } else if(_batchNumber == 3) {
            baseValue = _getRandom(4, 80);
        } else if(_batchNumber == 4) {
            baseValue = _getRandom(4, 75);
        } else if(_batchNumber == 5) {
            baseValue = _getRandom(9, 70);
        } else if(_batchNumber == 6) {
            baseValue = _getRandom(4, 60);
        } else if(_batchNumber == 7) {
            baseValue = _getRandom(9, 50);
        } else if(_batchNumber == 8) {
            baseValue = _getRandom(9, 40);
        } else if(_batchNumber == 9) {
            baseValue = _getRandom(9, 30);
        } else {
            baseValue = _getRandom(19, 20);
        }

        return baseValue;
    }

    /** @notice Gets the bloodline of a horse based on the bloodline of the parents
      * @param _male ID of the father
      * @param _female ID of the mother
      * @return bytes32 representing the bloodline of the horse
     */
    function getBloodlineFromParents(bytes32 _male, bytes32 _female) public view returns(bytes32) {
        return bloodlines[keccak256(abi.encodePacked(_male, _female))];
    }

    function _getRandom(uint256 _num, uint256 _deleteFrom) private view returns(uint256) {
        uint256 rand = uint256(blockhash(block.number - 1)) % _num + 1;

        return _deleteFrom.sub(rand);
    }
}
