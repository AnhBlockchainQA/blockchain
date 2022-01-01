// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "../interfaces/ICore.sol";
import "../interfaces/IHorseData.sol";
import "../interfaces/IBreedTypes.sol";
import "./EIP712MetaTransaction.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract StudServiceV5 is AccessControl, EIP712MetaTransaction, Pausable {
    using SafeMath for uint256;

    bytes32 public constant STUD_OWNERS_ROLE = bytes32("stud_owners");
    bytes32 public constant STUD_OWNERS_ADMIN_ROLE = bytes32("stud_owners_admin");
    bytes32 public constant STUD_CONTRACTS_ROLE = bytes32("stud_contracts");
    bytes32 public constant STUD_CONTRACTS_ADMIN_ROLE = bytes32("stud_contracts_admin");

    uint256 private _baseFee = 0.075 ether;
    uint256 private _defaultDuration = 86400;
    uint256[] private _horsesInStud;

    ICore private _core;
    IHorseData private _horseData;
    IBreedTypes private _breedTypes;

    struct StudInfo {
        bool inStud;
        uint256 matingPrice;
        uint256 duration;
        uint256 studCreatedAt;
    }

    mapping(uint256 => bool) private _timeframes;
    mapping(uint256 => StudInfo) private _studs;
    mapping(uint256 => uint256) private _horseIndex;
    mapping(bytes32 => uint256) private _bloodlineWeights;
    mapping(bytes32 => uint256) private _breedTypeWeights;

    event HorseInStud(uint256 horseId, uint256 matingPrice, uint256 duration, uint256 timestamp);
    event HorseRemovedFromStud(uint256 horseId, uint256 timestamp);

    // -----------------------------------------
    // CONSTRUCTOR
    // -----------------------------------------

    constructor(
        ICore core,
        IHorseData horseData,
        IBreedTypes breedTypes
    ) {
        // Set core and BreedTypes contracts
        _core = core;
        _horseData = horseData;
        _breedTypes = breedTypes;

        // Nakamoto - Szabo - Finney - Buterin
        _bloodlineWeights[bytes32("N")] = 180;
        _bloodlineWeights[bytes32("S")] = 120;
        _bloodlineWeights[bytes32("F")] = 40;
        _bloodlineWeights[bytes32("B")] = 15;

        // Genesis - Legendary - Exclusive - Elite - Cross - Pacer
        _breedTypeWeights[bytes32("genesis")] = 180;
        _breedTypeWeights[bytes32("legendary")] = 150;
        _breedTypeWeights[bytes32("exclusive")] = 120;
        _breedTypeWeights[bytes32("elite")] = 90;
        _breedTypeWeights[bytes32("cross")] = 80;
        _breedTypeWeights[bytes32("pacer")] = 60;

        _timeframes[86400] = true;
        _timeframes[259200] = true;
        _timeframes[604800] = true;

        // Access Control
        _setRoleAdmin(STUD_OWNERS_ROLE, STUD_OWNERS_ADMIN_ROLE);
        _setRoleAdmin(STUD_CONTRACTS_ROLE, STUD_CONTRACTS_ADMIN_ROLE);

        // Grants role to the caller
        _setupRole(STUD_OWNERS_ADMIN_ROLE, _msgSender());
        _setupRole(STUD_CONTRACTS_ADMIN_ROLE, _msgSender());
    }

    modifier onlyOwners() {
        require(hasRole(STUD_OWNERS_ROLE, _msgSender()), "StudService: unauthorized owner");
        _;
    }

    modifier onlyOwnersAdmins() {
        require(hasRole(STUD_OWNERS_ADMIN_ROLE, _msgSender()), "StudService: unauthorized owner admin");
        _;
    }

    modifier onlyAuthorizedWallets(uint256 _horseId) {
        require(
            _msgSender() == _core.ownerOf(_horseId) ||
                hasRole(STUD_CONTRACTS_ROLE, _msgSender()) ||
                hasRole(STUD_OWNERS_ROLE, _msgSender()),
            "StudService: unauthorized"
        );
        _;
    }

    // -----------------------------------------
    // SETTERS
    // -----------------------------------------

    /**
    @notice Puts a horse into stud mode
    @param _horseId ID of the horse to put in stud
    @param _matingPrice Price the horse will be in Stud for
    @param _duration Duration the horse will be in stud for
     */
    function putInStud(
        uint256 _horseId,
        uint256 _matingPrice,
        uint256 _duration
    ) external onlyAuthorizedWallets(_horseId) whenNotPaused() {
        _putInStud(_horseId, _matingPrice, _duration);
    }

    /**
    @notice Removes a horse from stud
    @param _horseId ID of the horse to remove from stud
     */
    function removeFromStud(uint256 _horseId) external onlyAuthorizedWallets(_horseId) whenNotPaused() {
        require(isHorseInStud(_horseId), "StudService: horse is not in stud");
        _deleteHorseFromStud(_horseId);

        emit HorseRemovedFromStud(_horseId, block.timestamp);
    }

    // -----------------------------------------
    // Views
    // -----------------------------------------

    /**
    @notice Gets the minimum breed price for a horse
    @param _horseId ID of the horse to get minimum breed price of
    @return uint256 Representing the minimum breed price of the horse
     */
    function getMinimumBreedPrice(uint256 _horseId) public view returns (uint256) {
        bytes32 breedType = _breedTypes.getBreedType(_horseId);

        // If the horse exists and the returned value from breed type is the default one (0x00000...)
        // it means it is a genesis horse. Otherwise we will just stick to the value returned by the call
        if (breedType == bytes32(0)) {
            breedType = bytes32("genesis");
        }

        // Get horse data
        bytes32 bloodline = _horseData.getBloodline(_horseId);
        uint256 bloodlineWeight = _bloodlineWeights[bloodline].mul(0.80 ether).div(100);
        uint256 breedWeight = _breedTypeWeights[breedType].mul(0.20 ether).div(100);

        return bloodlineWeight.add(breedWeight).mul(_baseFee).div(1 ether);
    }

    /**
    @notice Gets information about a horse's stud
    @param _horseId ID of the horse to get stud info of
    @return bool Representing horse's stud availability
    @return uint256 Representing the mating price of the horse
    @return uint256 Representing the duration of the horse in stud
    @return uint256 Representing the time the horse was put in stud
     */
    function getStudInfo(uint256 _horseId)
        external
        view
        returns (
            bool,
            uint256,
            uint256,
            uint256
        )
    {
        StudInfo memory stud = _studs[_horseId];
        return (stud.inStud, stud.matingPrice, stud.duration, stud.studCreatedAt);
    }

    /**
    @notice Returns the index a horse has in the stud list
    @param _horseId ID of the horse to get index of
    @return uint256 Representing index of the horse in stud list
     */
    function getHorseIndex(uint256 _horseId) external view returns (uint256) {
        return _horseIndex[_horseId];
    }

    /**
    @notice Returns the default duration the contract uses as a fallback
    @return uint256 Representing the default duration
     */
    function getDefaultDuration() external view returns (uint256) {
        return _defaultDuration;
    }

    /**
    @notice Gets the weight a specific breed type has
    @param _breedType Breed Type to use
    @return uint256 Representing the weight of the breed type
     */
    function getBreedTypeWeight(bytes32 _breedType) external view returns (uint256) {
        return _breedTypeWeights[_breedType];
    }

    /**
    @notice Gets the weight a specific bloodline has
    @param _bloodline The bloodline to use
    @return uint256 Representing the weight of the bloodline
     */
    function getBloodlineWeight(bytes32 _bloodline) external view returns (uint256) {
        return _bloodlineWeights[_bloodline];
    }

    /**
    @notice Checks the amount of horses in stud
    @return uin256[] Representing a list of IDs of horses in stud
     */
    function getHorsesInStud() external view returns (uint256[] memory) {
        return _horsesInStud;
    }

    /**
    @notice Gets mating price of a horse in stud
    @param _horseId ID of the horse to check mating price of
    @return uint256 Representing the mating price of the horse
     */
    function getMatingPrice(uint256 _horseId) external view returns (uint256) {
        return _studs[_horseId].matingPrice;
    }

    /**
    @notice Gets the stud time of a horse
    @param _horseId ID of the horse to get duration of
    @return uint256 Representing the time the horse is in stud for
     */
    function getStudTime(uint256 _horseId) external view returns (uint256) {
        return _studs[_horseId].duration;
    }

    /**
    @notice Gets the base fee
    @return uint256 Representing the base fee
     */
    function getBaseFee() external view returns (uint256) {
        return _baseFee;
    }

    /**
    @notice Gets the Core contract address
    @return address Representing the Core contract
     */
    function getCore() external view returns (address) {
        return address(_core);
    }

    /**
    @notice Gets the BreedTypes contract address
    @return address Representing the Breed Types contract
     */
    function getBreedTypes() external view returns (address) {
        return address(_breedTypes);
    }

    /**
    @notice Checks whether or not a horse is in stud
    @param _horseId ID of the horse to use
    @return bool Representing stud status of the horse
     */
    function isHorseInStud(uint256 _horseId) public view returns (bool) {
        return _studs[_horseId].inStud;
    }

    /**
    @notice Checks whether or not a timeframe exists
    @param _duration Duration to check
    @return bool Representing the timeframe existence
     */
    function isTimeframeExist(uint256 _duration) external view returns (bool) {
        return _timeframes[_duration];
    }

    // -----------------------------------------
    // PRIVATE
    // -----------------------------------------

    // Core does not provide getHorseSex()
    function _getHorseSex(uint256 _horseId) private view returns (bytes32) {
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
        ) = _core.getHorseData(_horseId);

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

    function _putInStud(
        uint256 _horseId,
        uint256 _matingPrice,
        uint256 _duration
    ) private {
        // We're checking the horse exists because we're relying on the breed type for genesis to be a default value.
        // this way we don't get false positives for horses that don't exist
        require(_core.tokenExists(_horseId), "StudService: horse does not exist");
        require(bytes32("M") == _getHorseSex(_horseId), "StudService: horse is not male");
        require(!_studs[_horseId].inStud, "StudService: horse is in stud");

        uint256 _minimumBreedPrice = getMinimumBreedPrice(_horseId);
        require(_matingPrice >= _minimumBreedPrice, "StudService: mating price lower than minimum breed price");

        uint256 durationToUse = _duration;

        // if sender is not admin, and specified timeframe does not exist, fallback to default
        if (!_timeframes[_duration]) {
            durationToUse = _defaultDuration;
        }

        // if sender has role, any time frame will be available
        if (hasRole(STUD_OWNERS_ROLE, _msgSender())) {
            durationToUse = _duration;
        }

        _studs[_horseId] = StudInfo(true, _matingPrice, durationToUse, block.timestamp);

        _horsesInStud.push(_horseId);
        _horseIndex[_horseId] = _horsesInStud.length.sub(1);

        emit HorseInStud(_horseId, _matingPrice, durationToUse, block.timestamp);
    }

    function _deleteHorseFromStud(uint256 _horseId) private {
        uint256 index = _horseIndex[_horseId];
        uint256 lastHorseIndex = _horsesInStud.length.sub(1);
        uint256 lastHorse = _horsesInStud[lastHorseIndex];

        // We need to reassign the index of the last horse, otherwise it'd be out of bounds
        // and the transaction will fail.
        _horsesInStud[index] = lastHorse;
        _horseIndex[lastHorse] = index;

        _horsesInStud.pop(); // This removes the last item from the list and reduces its length

        delete _studs[_horseId];
    }

    // -----------------------------------------
    // Restricted
    // -----------------------------------------

    /**
    @notice Grants a role to an account without the need to go through admin verification. This is useful in case we need to have more than
    one admin account for the same role. Allowing to easily switch accounts.
    @param _role Role to grant
    @param _account Account to grant _role
    */
    function grantRoleAdmin(bytes32 _role, address _account) external onlyOwnersAdmins() {
        _setupRole(_role, _account);
    }

    /**
    @notice Puts a horse in stud with admin permissions
    @param _horseId ID of the horse to put in Stud
    @param _matingPrice Mating price of the horse
    @param _duration Duration the horse will be in Stud for
     */
    function adminPutInStud(
        uint256 _horseId,
        uint256 _matingPrice,
        uint256 _duration
    ) external onlyOwners() {
        _putInStud(_horseId, _matingPrice, _duration);
    }

    /**
    @notice Sets breed types contract address
    @param breedTypes_ Address of the breed type contract
     */
    function setBreedTypesAddress(IBreedTypes breedTypes_) external onlyOwners() {
        require(address(breedTypes_) != address(0), "StudService: invalid breedtypes contract address");

        _breedTypes = breedTypes_;
    }

    /**
    @notice Sets address of the Core contract
    @param core_ Address of the Core contract
     */
    function setCoreAddress(ICore core_) external onlyOwners() {
        require(address(core_) != address(0), "StudService: invalid core contract address");

        _core = core_;
    }

    /**
    @notice Sets breed type weight
    @param _breedType Breed type to use
    @param _weight Weight to use for the breed type
     */
    function setBreedTypeWeight(bytes32 _breedType, uint256 _weight) external onlyOwners() {
        _breedTypeWeights[_breedType] = _weight;
    }

    /**
    @notice Sets the weight for a bloodline
    @param _bloodline Bloodline to use
    @param _weight Weight to use for the bloodline
     */
    function setBloodlineWeight(bytes32 _bloodline, uint256 _weight) external onlyOwners() {
        _bloodlineWeights[_bloodline] = _weight;
    }

    /**
    @notice Sets the default duration to fallback to
    @param _newDefaultDuration Duration to use
     */
    function setDefaultDuration(uint256 _newDefaultDuration) external onlyOwners() {
        _defaultDuration = _newDefaultDuration;
    }

    /**
    @notice Sets the base fee
    @param baseFee_ Base fee to use
     */
    function setBaseFee(uint256 baseFee_) external onlyOwners() {
        _baseFee = baseFee_;
    }

    /**
    @notice Makes another timeframe available to use
    @dev The breeding contract would need to be updated to handle this timeframe as well
    @param _secondsFrame Timeframe in seconds to use
     */
    function addTimeFrame(uint256 _secondsFrame) external onlyOwners() {
        require(_secondsFrame > 0, "StudService: invalid seconds frame");
        require(!_timeframes[_secondsFrame], "StudService: seconds frame already active");

        _timeframes[_secondsFrame] = true;
    }

    /**
    @notice Removes a previously set timeframe
    @dev It might not be necessary to update the Breeding contract after this however it'd be a good idea to maintain some kind of sync between these two contracts
    @param _secondsFrame Timeframe in seconds to remove
     */
    function removeTimeFrame(uint256 _secondsFrame) external onlyOwners() {
        require(_timeframes[_secondsFrame], "StudService: seconds frame is not found");

        _timeframes[_secondsFrame] = false;
    }

    /* INTERNAL OVERRIDES */

    /**
     * @dev _msgSender() is used through other contracts such as the ERC721 one. It is overridable and since
     * we want to support MetaTransactions we need to make sure that the logic applied by the msgSender() function
     * is used instead of the _msgSender() one. We're going to keep using _msgSender() where we need to nonetheless
     * and just let it forward to msgSender()
     * @return sender address of the caller
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
