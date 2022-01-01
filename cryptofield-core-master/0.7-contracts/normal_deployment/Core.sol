// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC721/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../interfaces/IHorseData.sol";
import "./EIP712MetaTransaction.sol";

/// @title Core contract for ZED NFTs
/// @author The VHS team
contract Core is AccessControl, ERC721Pausable, EIP712MetaTransaction {
    using SafeMath for uint256;

    bytes32 horseType;
    bytes32 private gender; // First horse is a male.
    bytes32[2] private gen;
    bytes32 public constant CORE_OWNERS_ROLE = bytes32("core_owners");
    bytes32 public constant CORE_CONTRACTS_ROLE = bytes32("core_contracts");
    bytes32 public constant CORE_OWNERS_ADMIN_ROLE = bytes32("core_owners_admin");
    bytes32 public constant CORE_CONTRACTS_ADMIN_ROLE = bytes32("core_contracts_admin");
    bytes32 public constant DEFAULT_OFFSPRING_NAME = bytes32("Unnamed Foal");

    uint256 constant GENOTYPE_CAP = 268;
    uint256 private _burnCount; // Tracks how many tokens have been burnt

    IHorseData private _horseData;

    struct Horse {
        address initialOwner;

        uint256 genotype;
        uint256 baseValue;
        uint256 timestamp;

        bytes32 bloodline;
        bytes32 sex;
        bytes32 hType;
        bytes32 name;
        bytes32 color;
    }

    mapping(uint256 => Horse) public horses;
    mapping(bytes32 => bool) public isNameTaken;

    event LogGOPCreated(address _buyer, uint256 _timestamp, uint256 _tokenId);
    event LogMintTokenWithHorseData(address _owner, uint256 _tokenId);
    event LogMintTokenWithHorseDataBatch(uint256 _tokenAmount);
    event LogSetHorseName(uint256 _tokenId, bytes32 _name);
    event LogSetHorseNameBatch(uint256 _tokenAmount);

    constructor(IHorseData horseData_) ERC721("ZED Horse", "ZED") {
        _horseData = horseData_;

        gender = bytes32("F");
        gen = [
            bytes32("M"),
            bytes32("F")
        ];

        _setBaseURI("https://api.zed.run/api/v1/horses/metadata/");

        // Access Control
        _setRoleAdmin(CORE_OWNERS_ROLE, CORE_OWNERS_ADMIN_ROLE);
        _setRoleAdmin(CORE_CONTRACTS_ROLE, CORE_CONTRACTS_ADMIN_ROLE);

        // Grants role to the caller
        _setupRole(CORE_OWNERS_ADMIN_ROLE, _msgSender());
        _setupRole(CORE_CONTRACTS_ADMIN_ROLE, _msgSender());
    }

    modifier onlyOwners() {
        require(hasRole(CORE_OWNERS_ROLE, _msgSender()), "Core: unauthorized");
        _;
    }

    modifier onlyContracts() {
        require(hasRole(CORE_CONTRACTS_ROLE, _msgSender()), "Core: unauthorized");
        _;
    }

    modifier onlyOwnersAdmins() {
        require(hasRole(CORE_OWNERS_ADMIN_ROLE, _msgSender()), "Core: unauthorized");
        _;
    }

    /*
    @notice Mints a token with custom parameters
    @param _owner Address of who's going to receive the token
    @param _genotype The genotype that's going to be assigned to the token
    @param _gender The gender that the horse will receive
    */
    function mintCustomHorse(
        address _owner,
        uint256 _genotype,
        bytes32 _gender,
        bytes32 _name,
        bytes32 _color
    ) external onlyContracts() whenNotPaused() {
        require(_genotype >= 1 && _genotype <= 10, "Core: gen out of bounds");
        require(!isNameTaken[_name], "Core: name already taken");

        isNameTaken[_name] = true;

        uint256 tokenId = nextTokenId();
        uint256 baseValue = _horseData.getBaseValue(_genotype);
        bytes32 bloodline = _horseData.getBloodline(_genotype);

        Horse memory h;
        h.timestamp = block.timestamp;
        h.initialOwner = _owner;
        h.baseValue = baseValue;
        h.genotype = _genotype;
        h.bloodline = bloodline;
        h.name = _name;
        h.color = _color;

        if(_gender == bytes32("Male")) {
            h.sex = gen[0];
            h.hType = bytes32("Colt");
        } else {
            h.sex = gen[1];
            h.hType = bytes32("Filly");
        }

        horses[tokenId] = h;

        _doMintToken(_owner, tokenId);

        emit LogGOPCreated(_owner, block.timestamp, tokenId);
    }

    /*
    @notice Mints a token specifically coming from Breeding
    @dev This has some pre-defined values in contrast to above's method
    @param _owner Address of who's going to receive the token
    @param _male ID of the male NFT
    @param _female ID of the female NFT
    */
    function mintOffspring(
        address _owner,
        uint256 _male,
        uint256 _female,
        bytes32 _color
    ) external onlyContracts() whenNotPaused() {
        uint256 tokenId = nextTokenId();
        bytes32 randGender;

        // Creates a 'random' gender.
        // This won't affect Genesis horses.
        if(_getRandGender() == 0) {
            randGender = gen[0]; // Male
            horseType = bytes32("Colt");
        } else {
            randGender = gen[1];
            horseType = bytes32("Filly"); // Female
        }

        Horse storage male = horses[_male];
        Horse storage female = horses[_female];

        // Change horse type of parents
        if(male.hType != bytes32("Stallion")) {
            male.hType = bytes32("Stallion");
        }

        if(female.hType != bytes32("Mare")) {
            female.hType = bytes32("Mare");
        }

        Horse memory horse;
        horse.initialOwner = _owner;
        // The use of 'block.timestamp' here shouldn't be a concern since that's only used for the timestamp of a horse
        // which really doesn't have much effect on the horse itself.
        horse.timestamp = block.timestamp;
        horse.sex = randGender;
        horse.genotype = _getType(male.genotype, female.genotype);
        horse.bloodline = _horseData.getBloodlineFromParents(male.bloodline, female.bloodline);
        horse.hType = horseType;
        horse.name = DEFAULT_OFFSPRING_NAME;
        horse.color = _color;

        horses[tokenId] = horse;

        _doMintToken(_owner, tokenId);
    }

    /*
    @notice Burns a token owned by msg.sender
    @param _tokenId ID of the token to burn
    */
    function burn(uint256 _tokenId) external whenNotPaused() {
        require(_exists(_tokenId), "Core: token does not exist");
        require(ownerOf(_tokenId) == _msgSender(), "Core: not owner of token");

        _burnCount += 1;

        delete horses[_tokenId];

        _burn(_tokenId);
    }

    /* VIEWS */
    /*
    @notice Checks whether or not _tokenId exists
    @param _tokenId ID of the token to check
    @return Boolean indicating if the token exists
    */
    function tokenExists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    /*
    @notice Returns the next token ID
    @return Integer indicating the next token ID
    */
    function nextTokenId() public view returns(uint256) {
        return totalSupply().add(_burnCount);
    }

    /*
    @notice Gets data from a token
    @param _tokenId ID of the token to fetch information for
    @return Tuple with all horse information
    */
    function getHorseData(
        uint256 _tokenId
    )
    external
    view
    returns(bytes32, uint256, uint256, uint256, bytes32, bytes32, bytes32, bytes32, address) {
        Horse memory h = horses[_tokenId];

        return (
            h.sex,
            h.baseValue,
            h.timestamp,
            h.genotype,
            h.bloodline,
            h.hType,
            h.name,
            h.color,
            h.initialOwner
        );
    }

    function getBaseValue(uint256 _horseId) external view returns(uint256) {
        return horses[_horseId].baseValue;
    }

    /* PRIVATE FUNCTIONS */
    /*
    @param _max Upper bound integer
    @return Random integer between 1 and max
    */
    function _getRand(uint256 _max) private view returns(uint256) {
        return uint256(blockhash(block.number - 1)) % _max + 1;
    }

    /*
    @return Integer with a random number between 1 and 50.
    */
    function _getRand() private view returns(uint256) {
        return uint256(blockhash(block.number - 1)) % 50 + 1;
    }

    /*
    @dev This function returns either 0 or 1, this can be used to select a 'random' gender.
    @return Random integer between 0 and 1
    */
    function _getRandGender() private view returns(uint256) {
        return uint256(blockhash(block.number - 1)) % 2;
    }

    /*
    @dev Calculates the genotype for an offspring based on the type of the parents.
    @dev It returns the Genotype for an offspring unless it is greater than the cap, otherwise it returns the CAP.
    @param _maleGT Genotype of the male NFT
    @param _femaleGT Genotype of the female NFT
    @return Integer representing a genotype
    */
    function _getType(uint256 _maleGT, uint256 _femaleGT) private pure returns(uint256) {
        // We're not going to run into overflows here since we have a genotype cap.
        uint256 geno = _maleGT + _femaleGT;
        if(geno > GENOTYPE_CAP) return GENOTYPE_CAP;
        return geno;
    }

    /*
    @param _i Integer to convert to string
    @return Integer parsed as string
    */
    function _uint2str(uint _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    /*
    @param _a First string
    @param _b Rest of the string
    @return A single concatenated string
    */
    function _uriStringConcat(string memory _a, string memory _b)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(_a, _b));
    }

    /*
    @dev Internal function for token minting and URI setting
    @param _owner Owner of the token to be minted
    @param _tokenId ID of the token to be minted
    */
    function _doMintToken(address _owner, uint256 _tokenId) private {
        _mint(_owner, _tokenId);
        _setTokenURI(_tokenId, _uint2str(_tokenId));
    }

    /* ADMIN FUNCTIONS */
    /*
    @dev Admin function meant to be used on edge cases to transfer a token from an address.
    @dev Helps combat frauds (Credit Cards, for example...)
    @param _tokenID the token ID
    @param _receiver the address that's going to receive the token
    */
    function adminTransferToken(uint256 _tokenID, address _receiver)
        external
        onlyOwners()
    {
        require(_receiver != address(0), "Core: address is null");

        address tokenOwner = ownerOf(_tokenID);

        _transfer(tokenOwner, _receiver, _tokenID);
    }

    /*
    @notice Pauses the contract
    */
    function pause() external onlyOwners() {
        _pause();
    }

    /*
    @notice Unpauses the contract
    */
    function unpause() external onlyOwners() {
        _unpause();
    }

    /*
    @notice Set the horse name for a given _tokenId
    @param _tokenId ID of the token to set the name for
    @param _name Name of the token
    */
    function setHorseName(uint256 _tokenId, bytes32 _name) external onlyOwners() {
        require(!isNameTaken[_name], "Core: name already taken");

        isNameTaken[_name] = true;

        horses[_tokenId].name = _name;

        LogSetHorseName(_tokenId, _name);
    }

    /*
    @dev Batch set the horse name for a given _tokenId
    @param _tokenIds List of IDs of tokens to mint
    @param _names List of names of to set for _tokenIds
    */
    function setHorseNameBatch(uint256[] memory _tokenIds, bytes32[] memory _names) onlyOwners() external {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(!isNameTaken[_names[i]], "Core: name already taken");

            isNameTaken[_names[i]] = true;

            horses[_tokenIds[i]].name = _names[i];
        }

        LogSetHorseNameBatch(_tokenIds.length);
    }

    /*
    @notice Batch mint token with given horse data.
    @dev string[] is not allowed
    */
    function mintTokenWithHorseDataBatch(address[] memory _owner, uint256[] memory _tokenId, bytes32[] memory _sex,
        uint256[] memory _baseValue, uint256[] memory _timestamp, uint256[] memory _genotype, bytes32[] memory _bloodline, bytes32[] memory _hType,
        bytes32[] memory _name, bytes32[] memory _color
    ) external onlyOwners() {
        for (uint256 i = 0; i < _owner.length; i++)
        {
            _doMintToken(_owner[i], _tokenId[i]);

            setHorseData(_owner[i], _tokenId[i], _sex[i], _baseValue[i], _timestamp[i],
                _genotype[i], _bloodline[i], _hType[i],
                _name[i], _color[i]
            );
        }

        emit LogMintTokenWithHorseDataBatch(_owner.length);
    }

    /*
    @dev Mint token with given horse data. Used for migration service
    */
    function mintTokenWithHorseData(address _owner, uint256 _tokenId, bytes32 _sex,
        uint256 _baseValue, uint256 _timestamp, uint256 _genotype, bytes32 _bloodline, bytes32 _hType,
        bytes32 _name, bytes32 _color
    ) external onlyOwners() {

        _doMintToken(_owner, _tokenId);

        setHorseData(_owner, _tokenId, _sex, _baseValue, _timestamp,
            _genotype, _bloodline, _hType,
            _name, _color
        );

        emit LogMintTokenWithHorseData(_owner, _tokenId);
    }

    /*
    @dev Set the horse data for a given _owner and _tokenId
    */
    function setHorseData(address _owner, uint256 _tokenId, bytes32 _sex,
        uint256 _baseValue, uint256 _timestamp, uint256 _genotype, bytes32 _bloodline, bytes32 _hType,
        bytes32 _name, bytes32 _color
    ) public onlyOwners() {
        Horse memory h;
        h.initialOwner = _owner;
        h.sex = _sex;
        h.baseValue = _baseValue;
        h.timestamp = _timestamp;
        h.genotype = _genotype;
        h.bloodline = _bloodline;
        h.hType = _hType;
        h.name = _name;
        h.color = _color;

        horses[_tokenId] = h;
    }

    /*
    @dev Change the uriBase for the token URI
    @dev Mostly used testnet
    @param _uriBase New URI base to use
    */
    function setBaseURI(string calldata _baseURI) external onlyOwners()
    {
        _setBaseURI(_baseURI);
    }

    /*
    @dev Grants a role to an account without the need to go through admin verification. This is useful in case we need to have more than
    one admin account for the same role. Allowing to easily switch accounts.
    @param _role Role to grant
    @param _account Account to grant _role
    */
    function grantRoleAdmin(bytes32 _role, address _account) external onlyOwnersAdmins() {
        _setupRole(_role, _account);
    }

    /** @dev Sets the _horseData address for the IHorseData interface
     */
    function setHorseDataAddress(IHorseData horseData_) external onlyOwners() {
        _horseData = horseData_;
    }

    /* INTERNAL OVERRIDES */

    /**
     * @dev _msgSender() is used through other contracts such as the ERC721 one. It is overridable and since
     * we want to support MetaTransactions we need to make sure that the logic applied by the msgSender() function
     * is used instead of the _msgSender() one. We're going to keep using _msgSender() where we need to nonetheless
     * and just let it forward to msgSender()
     * @return sender address of the caller
     */
    function _msgSender() internal override view returns(address payable sender) {
        sender = msgSender();
    }
}
