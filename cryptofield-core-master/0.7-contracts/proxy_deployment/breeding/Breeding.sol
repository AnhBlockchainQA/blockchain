// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./BreedingStorage.sol";

/**
@title Zed Breeding
@author The VHS team
 */
contract Breeding is BreedingStorage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event OffspringCreated(uint256 _father, uint256 _mother, uint256 _offspring, bytes32 _color);
    event BreedingFunds(uint256 _studOwner, uint256 _racesPool, uint256 _zed);

    /**
    @dev Initializes contract's state, acts as a constructor
    @param _core Address of the Core contract
    @param _studService Address of the Stud Service contract
    @param _breedTypes Address of the BreedTypes contract
    @param _poolAddress Address of Zed's Racing Pool
     */
    function initialize(
        ICore _core,
        IStudService _studService,
        IBreedTypes _breedTypes,
        IERC20 _weth,
        address _poolAddress,
        address _zedFeeWallet
    ) external initializer() {
        core = _core;
        studService = _studService;
        breedTypes = _breedTypes;
        weth = _weth;
        poolAddress = _poolAddress;
        zedFeeWallet = _zedFeeWallet;

        studOwnerPercentage[86400] = 40;
        studOwnerPercentage[259200] = 48;
        studOwnerPercentage[604800] = 56;

        prizePoolPercentage[86400] = 45;
        prizePoolPercentage[259200] = 37;
        prizePoolPercentage[604800] = 29;

        zedTakePercentage[86400] = 15;
        zedTakePercentage[259200] = 15;
        zedTakePercentage[604800] = 15;

        // Access Control
        _setRoleAdmin(BREEDING_OWNERS_ROLE, BREEDING_OWNERS_ADMIN_ROLE);

        // Grants role to the caller
        _setupRole(BREEDING_OWNERS_ADMIN_ROLE, _msgSender());
    }

    modifier onlyOwners() {
        require(hasRole(BREEDING_OWNERS_ROLE, _msgSender()), "Breeding: unauthorized owner");
        _;
    }

    modifier onlyOwnersAdmins() {
        require(hasRole(BREEDING_OWNERS_ADMIN_ROLE, _msgSender()), "Breeding: unauthorized owner admin");
        _;
    }

    /**
    @notice Mixes two horses to create an offspring
    @dev We're sending the _breedPrice as a prameter which acts as the msg.value because we're using WETH
    as the payment method
    @param _maleId ID of the father
    @param _femaleId ID of the mother
    @param _color Color of the offspring
    @param _breedPrice Amount the user paid (WETH)
     */
    function mix(
        uint256 _maleId,
        uint256 _femaleId,
        bytes32 _color,
        uint256 _breedPrice
    ) external payable whenNotPaused() {
        require(core.tokenExists(_maleId) && core.tokenExists(_femaleId), "BR: horse don't exists");

        bytes32 horseSex1 = getHorseSex(_maleId);
        require(bytes32("M") == horseSex1, "Breeding: expected male horse but received female");

        bytes32 horseSex2 = getHorseSex(_femaleId);
        require(bytes32("F") == horseSex2, "Breeding: expected female horse but received male");

        require(studService.isHorseInStud(_maleId), "Breeding: male not in stud");
        // female's owner is offspring's owner
        address femaleOwner = core.ownerOf(_femaleId);

        require(_msgSender() == femaleOwner, "Breeding: female owner should be the initiator");

        address maleOwner = core.ownerOf(_maleId);
        uint256 matingPrice = studService.getMatingPrice(_maleId);

        // check if we should apply a discount
        if (maleOwner == femaleOwner) {
            // _msgSender() will only pay 35% of 'msg.value'
            require(_breedPrice >= matingPrice.sub(matingPrice.mul(35).div(100)), "Breeding: mating price not met");
        } else {
            require(_breedPrice >= matingPrice, "Breeding: mating price not met");
        }

        HorseBreed storage male = horseBreedById[_maleId];
        HorseBreed storage female = horseBreedById[_femaleId];

        require(_notBrothers(male, female), "Breeding: horses are brothers");
        require(_notParents(_maleId, _femaleId), "Breeding: horses are directly related");
        require(_notGrandparents(_maleId, _femaleId), "Breeding: horse is grandchild");

        male.offspringCounter += 1;
        female.offspringCounter += 1;

        // Work-around for the problem that method Core.mintOffspring() does not return tokenId
        uint256 offspringId = core.nextTokenId();
        require(!core.tokenExists(offspringId), "Breeding: offspringID already exists");
        core.mintOffspring(femaleOwner, _maleId, _femaleId, _color);

        // ? Do we want this require below?
        require(core.ownerOf(offspringId) == femaleOwner, "BR offspringId owner is not femaleOwner");
        ////////////////////////////////////////////////////////////////////////

        // put the newly generated token into the mapping for both parents
        offspringsOf[_maleId][offspringId] = true;
        offspringsOf[_femaleId][offspringId] = true;

        // offspring's data
        HorseBreed storage o = horseBreedById[offspringId];
        o.parents = [_maleId, _femaleId];

        // save offspring's ID to parents
        male.offsprings.push(offspringId);
        female.offsprings.push(offspringId);

        // Manually save ID of each on the mapping, looks uglier but this way we can perform checks
        // more efficiently by just checking IDs instead of looping or doing another mechanism that could
        // be more expensive.
        o.grandparents[male.parents[0]] = true;
        o.grandparents[male.parents[1]] = true;
        o.grandparents[female.parents[0]] = true;
        o.grandparents[female.parents[1]] = true;

        _setBaseValue(offspringId, _getBaseValue(_maleId, _femaleId));
        breedTypes.generateBreedType(offspringId, _maleId, _femaleId);

        _sendBreedingFunds(maleOwner, femaleOwner, _maleId, _breedPrice);

        emit OffspringCreated(_maleId, _femaleId, offspringId, _color);
    }

    /**
    @dev Convenient function to get the sex of a horse from the Core contract
    @param _horseId ID of the horse to fetch data for
    @return bytes32 representing the sex of the horse
     */
    function getHorseSex(uint256 _horseId) public view returns (bytes32) {
        (
            bytes32 horseSex,
            uint256 baseValue,
            uint256 timestamp,
            uint256 genotype,
            bytes32 bloodline,
            bytes32 hType,
            bytes32 name,
            bytes32 color,
            address initialOwner
        ) = core.getHorseData(_horseId);

        // To avoid compiler warning of unused variable
        baseValue = 0;
        timestamp = 0;
        genotype = 0;
        bloodline = bytes32("0");
        hType = bytes32("0");
        name = bytes32("0");
        color = bytes32("0");
        initialOwner = address(0);

        return horseSex;
    }

    /*
    @dev Returns a horse stats for breeding.
    */
    function getHorseOffspringStats(uint256 _horseId) external view returns (uint256) {
        return horseBreedById[_horseId].offspringCounter;
    }

    /** PRIVATES */

    /**
    @dev Returns the name of a horse from the Core contract
    @param _horseId ID of the horse to fetch data for
    @return bytes32 representing the name of the horse
     */
    function _getHorseName(uint256 _horseId) private view returns (bytes32) {
        (
            bytes32 horseSex,
            uint256 baseValue,
            uint256 timestamp,
            uint256 genotype,
            bytes32 bloodline,
            bytes32 hType,
            bytes32 name,
            bytes32 color,
            address initialOwner
        ) = core.getHorseData(_horseId);

        // To avoid compiler warning of unused variable
        baseValue = 0;
        timestamp = 0;
        genotype = 0;
        bloodline = bytes32("0");
        hType = bytes32("0");
        horseSex = bytes32("0");
        color = bytes32("0");
        initialOwner = address(0);

        return name;
    }

    /**
    @dev Sets the base value of a horse in the Core contract
    @param _offspringId ID of the offspring to set the base value of
    @param _newBaseValue New base value of _offspringId
     */
    function _setBaseValue(uint256 _offspringId, uint256 _newBaseValue) private {
        (
            bytes32 horseSex,
            uint256 baseValue,
            uint256 timestamp,
            uint256 genotype,
            bytes32 bloodline,
            bytes32 hType,
            bytes32 name,
            bytes32 color,
            address initialOwner
        ) = core.getHorseData(_offspringId);

        // To avoid compiler warning of unused variable
        baseValue = 0;

        // Core need to grant CORE_OWNERS_ROLE for Breeding contract
        core.setHorseData(
            initialOwner,
            _offspringId,
            horseSex,
            _newBaseValue,
            timestamp,
            genotype,
            bloodline,
            hType,
            name,
            color
        );
    }

    /**
    @notice Sends the funds of the operation to everyone involved. Pool address, owner of male horse and owner of female horse
    @dev Alters the breed price of the horse depending on the type of stable (Public, private)

    Private: Same owner of both horses
    Public: Different owners
    @param _maleOwner Address of the owner of the male horse
    @param _femaleOwner Address of the owner of the female horse
    @param _breedPrice Amount paid by the sender of the transaction
     */
    function _sendBreedingFunds(
        address _maleOwner,
        address _femaleOwner,
        uint256 _male,
        uint256 _breedPrice
    ) private {
        if (_maleOwner == _femaleOwner) {
            // Private or own stable
            // We won't send anything to the Stud Owner AKA _msgSender()

            // 70% to the prize pool address
            uint256 poolTake = _breedPrice.mul(70).div(100);
            // 30% to Zed
            uint256 zedTake = _breedPrice.mul(30).div(100);

            weth.safeTransferFrom(_msgSender(), poolAddress, poolTake);
            weth.safeTransferFrom(_msgSender(), zedFeeWallet, zedTake);

            emit BreedingFunds(0, poolTake, zedTake);
        } else {
            // Other stables - take into consideration stud time of the horse
            uint256 studTime = studService.getStudTime(_male);
            uint256 studOwner = studOwnerPercentage[studTime];
            uint256 prizePool = prizePoolPercentage[studTime];
            uint256 zed = zedTakePercentage[studTime];

            //
            uint256 studOwnerTake = _breedPrice.mul(studOwner).div(100);
            uint256 poolTake = _breedPrice.mul(prizePool).div(100);
            uint256 zedTake = _breedPrice.mul(zed).div(100);

            // Stud owner.
            weth.safeTransferFrom(_msgSender(), _maleOwner, studOwnerTake);

            // Prize pool.
            weth.safeTransferFrom(_msgSender(), poolAddress, poolTake);

            // Zed
            weth.safeTransferFrom(_msgSender(), zedFeeWallet, zedTake);

            emit BreedingFunds(studOwnerTake, poolTake, zedTake);
        }
    }

    /**
    @dev Checks whether two given horses are brothers or not.
    @dev Having the same parents obviously makes them directly related.
    @param _male Struct representing the male horse
    @param _female Struct representing the female horse
    @return boolean Indicating whether or not horses are brothers
    */
    function _notBrothers(HorseBreed storage _male, HorseBreed storage _female) private view returns (bool) {
        // We're going to avoid the case where parents are ID 0
        if (_male.parents[0] == 0 || _male.parents[1] == 0) return true;
        if (_female.parents[0] == 0 || _female.parents[1] == 0) return true;

        // Hash of both parents shouldn't be the same.
        return keccak256(abi.encodePacked(_male.parents)) != keccak256(abi.encodePacked(_female.parents));
    }

    /**
    @notice Checks whether two horses are directly related, i.e. one being an offspring of another.
    @dev The process for this verification is simple, we track offsprings of each horse in a mapping
    here we check if either horse is an offspring of the other one, if true then we revert the op.
    @param _male ID of the male horse
    @param _female ID of the female horse
    @return boolean Indicating whether or not any of the horses is a parent of the other horse
    */
    function _notParents(uint256 _male, uint256 _female) private view returns (bool) {
        if (offspringsOf[_male][_female]) return false;
        if (offspringsOf[_female][_male]) return false;

        return true;
    }

    /**
    @notice Checks whether two horses are directly related, i.e. one being a grandparent of another.
    @dev We follow a similar approach as above, we just check for other's sex ID on the mapping
    of grandparents for a truthy value.
    @param _male ID of the male horse
    @param _female ID of the female horse
    @return boolean Indicating whether or not any of the horses is a grandparent of the other horse
    */
    function _notGrandparents(uint256 _male, uint256 _female) private view returns (bool) {
        HorseBreed storage m = horseBreedById[_male];
        HorseBreed storage f = horseBreedById[_female];

        if (m.grandparents[_female]) return false;
        if (f.grandparents[_male]) return false;

        return true;
    }

    /**
    @notice Gets a random number between two bounds.
    @param _num The inner bound
    @param _deleteFrom Maximum number it can generate
    @return uint256 Representing the number
    */
    function _getRandNum(uint256 _num, uint256 _deleteFrom) private returns (uint256) {
        nonce += 1;

        bytes32 randData = keccak256(abi.encodePacked(nonce, _msgSender(), blockhash(block.number - 1)));

        uint256 rand = (uint256(randData) % _num) + 1;

        return _deleteFrom.sub(rand);
    }

    /**
    @notice Computes the base value for an offspring
    @param _maleParent ID of the male horse
    @param _femaleParent ID of the female horse
    */
    function _getBaseValue(uint256 _maleParent, uint256 _femaleParent) private returns (uint256) {
        // Create the offspring baseValue
        uint256 percentage = _getRandNum(34, 65); // Creates a random number between 30 and 65.
        uint256 maleBaseValue = core.getBaseValue(_maleParent);
        uint256 femaleBaseValue = core.getBaseValue(_femaleParent);
        uint256 finalParents = maleBaseValue.add(femaleBaseValue);

        return finalParents.mul(percentage).div(100);
    }

    /** VIEWS */
    /**
    @notice Checks if any of the horses included are related.
    @param _male ID of the male horse
    @param _female ID of the female horse
    @return bool Indicating whether or not the horses are related
    @return string Indicating at what point they're related
    */
    function areHorsesRelated(uint256 _male, uint256 _female) external view returns (bool, string memory) {
        HorseBreed storage male = horseBreedById[_male];
        HorseBreed storage female = horseBreedById[_female];

        if (!_notBrothers(male, female)) {
            return (true, "brothers");
        }

        if (!_notParents(_male, _female)) {
            return (true, "parents");
        }

        if (!_notGrandparents(_male, _female)) {
            return (true, "grandparents");
        }

        return (false, "");
    }

    /**
    @param _horseId ID of the horse to fetch data for
    @return uint256[2] Representing the parents of the horse
    @return uint256[] Representing the IDs of offsprings this horse has
    @return uint256 Representing the number off offsprings this horse has
    */
    function breedingData(uint256 _horseId)
        external
        view
        returns (
            uint256[2] memory,
            uint256[] memory,
            uint256
        )
    {
        HorseBreed storage h = horseBreedById[_horseId];
        return (h.parents, h.offsprings, h.offspringCounter);
    }

    function getParents(uint256 _horseId) external view returns (uint256[2] memory) {
        return horseBreedById[_horseId].parents;
    }

    function getCore() external view returns (address) {
        return address(core);
    }

    function getBreedTypes() external view returns (address) {
        return address(breedTypes);
    }

    function getStudService() external view returns (address) {
        return address(studService);
    }

    function getPoolAddress() external view returns (address) {
        return poolAddress;
    }

    function getWethAddress() external view returns (IERC20) {
        return weth;
    }

    function isHorseAlreadyMigrated(uint256 horseId) external view returns (bool) {
        return isHorseMigrated[horseId];
    }

    /*  RESTRICTED */
    function setStudAndPrizePoolPercentage(
        uint256 _time,
        uint256 _studPercentage,
        uint256 _prizePoolPercentage,
        uint256 _zedTakePercentage
    ) external onlyOwners() {
        studOwnerPercentage[_time] = _studPercentage;
        prizePoolPercentage[_time] = _prizePoolPercentage;
        zedTakePercentage[_time] = _zedTakePercentage;
    }

    function setCore(address _core) external onlyOwners() {
        core = ICore(_core);
    }

    function setBreedTypesAddress(address _breedTypes) external onlyOwners() {
        breedTypes = IBreedTypes(_breedTypes);
    }

    function setStudServiceAddress(address _studService) external onlyOwners() {
        studService = IStudService(_studService);
    }

    function setPoolAddress(address _poolAddress) external onlyOwners() {
        poolAddress = _poolAddress;
    }

    /**
    @dev Used to migrate data of horses into this contract
    @param _offspringId ID of the offspring we're going to migrate data of
    @param _parents IDsof the parents of the horse, father being index 0 and mother index 1
    @param _offsprings List of the IDs of offsprings this horse has
    @param _offspringCounter Number of offsprings this horse has
    @param _fatherParents IDs of the parents of the father of this horse, father being index 0 and mother index 1
    @param _motherParents IDs of the parents of the mother of this horse, father being index 0 and mother index 1
    @param _offspringBreedType Breed type of _offspringId
     */
    function migrateData(
        uint256 _offspringId,
        uint256[2] memory _parents,
        uint256[] memory _offsprings,
        uint256 _offspringCounter,
        uint256[2] memory _fatherParents,
        uint256[2] memory _motherParents,
        bytes32 _offspringBreedType
    ) external onlyOwners() {
        require(!isHorseMigrated[_offspringId], "Breeding: horse has been migrated already");

        // Get horse breed data from previous contract
        // (uint256[2] memory parents, uint256[] memory offsprings, ) =
        //     oldBreedingContract.breedingData(_offspringId);

        // uint256 offspringCounter =
        //     oldBreedingContract.getHorseOffspringStats(_offspringId);

        uint256 fatherId = _parents[0];
        uint256 motherId = _parents[1];

        // Get horse grandparents ids from previous breeding contract
        // uint256[2] memory fatherParents =
        //     oldBreedingContract.getParents(fatherId);
        // uint256[2] memory motherParents =
        //     oldBreedingContract.getParents(motherId);

        // Save horse data on new storage
        HorseBreed storage offspring = horseBreedById[_offspringId];

        // Save offspring data
        offspring.parents = _parents;
        offspring.offsprings = _offsprings;
        offspring.offspringCounter = _offspringCounter;

        // Save grandparents
        // IMPORTANT
        // 0 index is FATHER
        // 1 index is MOTHER
        offspring.grandparents[_fatherParents[0]] = true;
        offspring.grandparents[_fatherParents[1]] = true;
        offspring.grandparents[_motherParents[0]] = true;
        offspring.grandparents[_motherParents[1]] = true;

        // put the newly generated token into the mapping for both parents
        offspringsOf[fatherId][_offspringId] = true;
        offspringsOf[motherId][_offspringId] = true;

        breedTypes.setBreedType(_offspringId, _offspringBreedType);

        // update the horse migration status
        isHorseMigrated[_offspringId] = true;
    }

    /**
    @dev Grants a role to an account without the need to go through admin verification. This is useful in case we need to have more than
    one admin account for the same role. Allowing to easily switch accounts.
    @param _role Role to grant
    @param _account Account to grant _role
    */
    function grantRoleAdmin(bytes32 _role, address _account) external onlyOwnersAdmins() {
        _setupRole(_role, _account);
    }

    /**
    @notice Changes address of the wallet that will receive fees for Zed
    @param _zedFeeWallet Address of the wallet to use
     */
    function changeZedFeeWallet(address _zedFeeWallet) external onlyOwnersAdmins() {
        zedFeeWallet = _zedFeeWallet;
    }

    /* INTERNAL OVERRIDES */
    /**
    @dev _msgSender() is used through other contracts such as the ERC721 one. It is overridable and since
    we want to support MetaTransactions we need to make sure that the logic applied by the msgSender() function
    is used instead of the _msgSender() one. We're going to keep using _msgSender() where we need to nonetheless
    and just let it forward to msgSender()
    @return sender address of the caller
     */
    function _msgSender() internal view override returns (address payable sender) {
        sender = msgSender();
    }

    /**
    @notice Pauses contract
     */
    function pause() external onlyOwnersAdmins() {
        _pause();
    }

    /**
    @notice Unpauses the contract
     */
    function unpause() external onlyOwnersAdmins() {
        _unpause();
    }
}
