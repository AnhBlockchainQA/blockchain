// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../normal_deployment/EIP712MetaTransaction.sol";
import "../../interfaces/IBreedTypes.sol";
import "../../interfaces/ICore.sol";
import "../../interfaces/IStudService.sol";

contract BreedingStorage is Initializable, AccessControl, EIP712MetaTransaction, Pausable {
    // we're going to use the funds on this address for races
    address internal poolAddress;
    address internal zedFeeWallet;

    uint256 internal nonce;

    bytes32 public constant BREEDING_OWNERS_ROLE = bytes32("breeding_owners");
    bytes32 public constant BREEDING_OWNERS_ADMIN_ROLE = bytes32("breeding_owners_admin");

    ICore internal core;
    IBreedTypes internal breedTypes;
    IStudService internal studService;
    IERC20 internal weth; // WETH contract

    // All this is subject to a change
    struct HorseBreed {
        uint256[2] parents;
        uint256[] offsprings;
        uint256 offspringCounter;
        mapping(uint256 => bool) grandparents;
    }

    // Maps the horseID to a specific HorseBreed struct.
    mapping(uint256 => HorseBreed) internal horseBreedById;

    // Tracks offsprings of each horse.
    mapping(uint256 => mapping(uint256 => bool)) internal offspringsOf;

    // maps percentages for stud duration to stud owner for PUBLIC STABLES
    mapping(uint256 => uint256) internal studOwnerPercentage;

    // maps percentages for stud duration to prize pool for PUBLIC STABLES
    mapping(uint256 => uint256) internal prizePoolPercentage;

    // Sets how much Zed will take depending on time a horse was in stud
    mapping(uint256 => uint256) internal zedTakePercentage;

    // protection for double re-migration
    mapping(uint256 => bool) internal isHorseMigrated;
}
