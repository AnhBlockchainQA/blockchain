// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;


import "@openzeppelin/contracts/access/AccessControl.sol";

/**
@title BreedTypes
@author The VHS Team
@dev BreedTypes contract to introduce different breeds to horses. Genesis horses are defined by the default
value since we can't update them all automatically once they're created at this point. bytes32(0) or "0x0000..." means
the horse is a 'genesis'
 */
contract BreedTypes is AccessControl {
    bytes32 public constant BREED_TYPES_OWNERS_ROLE = bytes32("breed_types_owners");
    bytes32 public constant BREED_TYPES_OWNERS_ADMIN_ROLE = bytes32("breed_types_owners_admin");
    bytes32 public constant BREED_TYPES_CONTRACTS_ROLE = bytes32("breed_types_contracts");
    bytes32 public constant BREED_TYPES_CONTRACTS_ADMIN_ROLE = bytes32("breed_types_contracts_admin");

    // Maps each horse ID to a breed type.
    mapping(uint256 => bytes32) public horseBreed;

    // Maps hash of parents breed type to another breed type
    mapping(bytes32 => bytes32) private _breedTypeMatrix;

    event BreedType(bytes32 _breed, uint256 _horseId);

    constructor() {
        _populateMatrix();

        // Access Control
        _setRoleAdmin(BREED_TYPES_OWNERS_ROLE, BREED_TYPES_OWNERS_ADMIN_ROLE);
        _setRoleAdmin(BREED_TYPES_CONTRACTS_ROLE, BREED_TYPES_CONTRACTS_ADMIN_ROLE);

        // Grants role to the caller
        _setupRole(BREED_TYPES_OWNERS_ADMIN_ROLE, _msgSender());
        _setupRole(BREED_TYPES_CONTRACTS_ADMIN_ROLE, _msgSender());
    }

    modifier onlyOwnersAdmins() {
        require(hasRole(BREED_TYPES_OWNERS_ADMIN_ROLE, _msgSender()), "BreedTypes: unauthorized owner admin");
        _;
    }

    modifier onlyOwnerOrContracts() {
        require(
            hasRole(BREED_TYPES_OWNERS_ROLE, _msgSender()) || hasRole(BREED_TYPES_CONTRACTS_ROLE, _msgSender()),
            "BreedTypes: unauthorized owner or contract"
        );
        _;
    }

    /** SETTERS */

    /**
    @notice Generates a breed type for an offspring based in the hash of the breed type of the parents
    @param _offspringId ID of the offspring to save the breed type for
    @param _fatherId ID of the parent of the offspring
    @param _motherId ID of the mother of the offspring
     */
    function generateBreedType(
        uint256 _offspringId,
        uint256 _fatherId,
        uint256 _motherId
    ) external onlyOwnerOrContracts() {
        // get hash from parent's types
        bytes32 fatherType = horseBreed[_fatherId];
        bytes32 motherType = horseBreed[_motherId];
        bytes32 typeFromHash = _breedTypeMatrix[keccak256(abi.encodePacked(fatherType, motherType))];

        horseBreed[_offspringId] = typeFromHash;

        emit BreedType(typeFromHash, _offspringId);
    }

    /**
    @notice Sets the breed type for a given _horseId
    @dev This is mostly used for Breeding migrations
    @param _horseId ID of the horse to set the breed type for
    @param _breedType Breed Type we're going to assign to _horseId
     */
    function setBreedType(uint256 _horseId, bytes32 _breedType) external onlyOwnerOrContracts() {
        horseBreed[_horseId] = _breedType;
    }

    /** VIEWS */

    /**
    @notice Returns breed type of a given horse
    @param _horseId ID Of the horse to fetch breed type for
    @return bytes32 Representing the breed type of the horse
     */
    function getBreedType(uint256 _horseId) public view returns (bytes32) {
        return horseBreed[_horseId];
    }

    /**
    @notice Gets breed type from state
    @dev This is used to verify the breed type matrix
    @param _firstType First Breed Type
    @param _secondType Second Breed Type
    @return bytes32 Representing the breed type from a hash
     */
    function getBreedTypeFromMatrix(bytes32 _firstType, bytes32 _secondType) external view returns(bytes32) {
        return _breedTypeMatrix[keccak256(abi.encodePacked(_firstType, _secondType))];
    }

    /** PRIVATE */

    /**
    @dev Populates the breed type matrix. The matrix is build by hashing two breed types which in the end is the combination
    of a parent and mother. Mostly used for breeding.
     */
    function _populateMatrix() private {
        // Horse Type Matrix
        // Genesis - Legendary - Exclusive - Elite - Cross - Pacer
        bytes32 genesis = bytes32(0);
        bytes32 legendary = bytes32("legendary");
        bytes32 exclusive = bytes32("exclusive");
        bytes32 elite = bytes32("elite");
        bytes32 cross = bytes32("cross");
        bytes32 pacer = bytes32("pacer");

        // genesis
        _breedTypeMatrix[keccak256(abi.encodePacked(genesis, genesis))] = legendary;
        _breedTypeMatrix[keccak256(abi.encodePacked(genesis, legendary))] = exclusive;
        _breedTypeMatrix[keccak256(abi.encodePacked(genesis, exclusive))] = exclusive;
        _breedTypeMatrix[keccak256(abi.encodePacked(genesis, elite))] = elite;
        _breedTypeMatrix[keccak256(abi.encodePacked(genesis, cross))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(genesis, pacer))] = pacer;

        // legendary
        _breedTypeMatrix[keccak256(abi.encodePacked(legendary, genesis))] = exclusive;
        _breedTypeMatrix[keccak256(abi.encodePacked(legendary, legendary))] = exclusive;
        _breedTypeMatrix[keccak256(abi.encodePacked(legendary, exclusive))] = elite;
        _breedTypeMatrix[keccak256(abi.encodePacked(legendary, elite))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(legendary, cross))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(legendary, pacer))] = pacer;

        // exclusive
        _breedTypeMatrix[keccak256(abi.encodePacked(exclusive, genesis))] = elite;
        _breedTypeMatrix[keccak256(abi.encodePacked(exclusive, legendary))] = elite;
        _breedTypeMatrix[keccak256(abi.encodePacked(exclusive, exclusive))] = elite;
        _breedTypeMatrix[keccak256(abi.encodePacked(exclusive, elite))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(exclusive, cross))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(exclusive, pacer))] = pacer;

        // elite
        _breedTypeMatrix[keccak256(abi.encodePacked(elite, genesis))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(elite, legendary))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(elite, exclusive))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(elite, elite))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(elite, cross))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(elite, pacer))] = pacer;

        // cross
        _breedTypeMatrix[keccak256(abi.encodePacked(cross, genesis))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(cross, legendary))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(cross, exclusive))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(cross, elite))] = cross;
        _breedTypeMatrix[keccak256(abi.encodePacked(cross, cross))] = pacer;
        _breedTypeMatrix[keccak256(abi.encodePacked(cross, pacer))] = pacer;

        // pacer
        _breedTypeMatrix[keccak256(abi.encodePacked(pacer, genesis))] = pacer;
        _breedTypeMatrix[keccak256(abi.encodePacked(pacer, legendary))] = pacer;
        _breedTypeMatrix[keccak256(abi.encodePacked(pacer, exclusive))] = pacer;
        _breedTypeMatrix[keccak256(abi.encodePacked(pacer, elite))] = pacer;
        _breedTypeMatrix[keccak256(abi.encodePacked(pacer, cross))] = pacer;
        _breedTypeMatrix[keccak256(abi.encodePacked(pacer, pacer))] = pacer;
    }

    /** RESTRICTED */

    /**
    @dev Grants a role to an account without the need to go through admin verification. This is useful in case we need to have more than
    one admin account for the same role. Allowing to easily switch accounts.
    @param _role Role to grant
    @param _account Account to grant _role
    */
    function grantRoleAdmin(bytes32 _role, address _account) external onlyOwnersAdmins() {
        _setupRole(_role, _account);
    }
}
