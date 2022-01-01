// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GOPCreatorV3 is Pausable, AccessControl {
    using SafeMath for uint256;

    address payable _fundsReceiver;

    bytes32 public constant GOP_OWNERS_ROLE = bytes32("gop_owners");
    bytes32 public constant GOP_OWNERS_ADMIN_ROLE = bytes32("gop_owners_admin");

    InterfaceCore private _core;

    mapping(uint256 => uint256) internal horsesForGen; // Saves amount of horses for specific genotype.
    mapping(bytes32 => bool) internal isCodeUsed; // Mapping for horse codes and check their availability.

    event ReceivedGOPFunds(
        address indexed _buyer,
        uint256 _paidAmount,
        bytes32 indexed _horseCode
    );

    event CodeStatusChanged(bytes32 indexed _horseCode, bool _codeStatus);

    constructor(address payable fundsReceiver_, InterfaceCore core_, address _blockchainBrain) {
        _core = core_;
        _fundsReceiver = fundsReceiver_;

        // Access Control
        _setRoleAdmin(GOP_OWNERS_ROLE, GOP_OWNERS_ADMIN_ROLE);

        _setupRole(GOP_OWNERS_ADMIN_ROLE, _msgSender());
        _setupRole(GOP_OWNERS_ROLE, _blockchainBrain);
    }

    modifier onlyOwners() {
        require(hasRole(GOP_OWNERS_ROLE, _msgSender()), "GOP: Unauthorized");
        _;
    }

    /*
    @dev Receives funds for a horse buy and emits an event to be catched by our event handler.
    @dev Sends '_horseCode' which will be handled by the back-end.
    */
    function receiveGOPFunds(bytes32 _horseCode)
        external
        payable
        whenNotPaused()
    {
        require(!isCodeUsed[_horseCode], "GOP: Code has already been used");

        isCodeUsed[_horseCode] = true;

        _fundsReceiver.transfer(msg.value);

        emit ReceivedGOPFunds(msg.sender, msg.value, _horseCode);
    }

    /*
    @dev Marks a code as used.
    @param _horseCode code we're marking as used
    */
    function markCodeAsUsed(bytes32 _horseCode)
        external
        onlyOwners()
        whenNotPaused()
    {
        require(!isCodeUsed[_horseCode], "GOP: Code has been used");

        isCodeUsed[_horseCode] = true;

        emit CodeStatusChanged(_horseCode, true);
    }

    /*
    @dev Marks a code as unused.
    @param _horseCode code we're marking as unused
    */
    function markCodeAsUnused(bytes32 _horseCode)
        external
        onlyOwners()
        whenNotPaused()
    {
        // Code must be used already before setting state back to false.
        require(isCodeUsed[_horseCode], "GOP: Code has not been used");

        isCodeUsed[_horseCode] = false;

        emit CodeStatusChanged(_horseCode, false);
    }

    /*
    @notice Creates a custom horse from the specified params. Mostly for marketing purposes.
    @notice This horse also counts for the 38.000 horses that'll get released.
    @param _owner Address that's getting the horse.
    @param _batch Batch that acts as the genotype, should only be between 1 and 10.
    @param _gender Horse gender
    @param _name Name of the horse
    @param _color Color of the horse
    */
    function createCustomHorse(
        address _owner,
        uint256 _batch,
        bytes32 _gender,
        bytes32 _name,
        bytes32 _color
    ) external onlyOwners() whenNotPaused() {
        require(horsesForGen[_batch] != 0, "GOP: Limit for genotype reached");

        horsesForGen[_batch] = horsesForGen[_batch].sub(1);

        _core.mintCustomHorse(_owner, _batch, _gender, _name, _color);
    }

    receive() external payable {}

    /*  GETTERS */

    /*
    @param _gen genotype or batch
    @return amount of horses remaining
    */
    function horsesRemaining(uint256 _gen) public view returns (uint256) {
        return horsesForGen[_gen];
    }

    /* RESTRICTED */

    /*
    @notice Set horses remaining for a given _gen
    @param _gen genotype or batch
    @param _amount horses remaining
    */
    function setHorsesRemaining(uint256 _gen, uint256 _amount)
        public
        onlyOwners()
        whenNotPaused()
    {
        horsesForGen[_gen] = _amount;
    }

    /*  RESTRICTED FUNCS    */
    /*
    @dev Changes the address that's receiving funds from sells
    @param _newReceiver new admin address that's receiving funds
    */
    function changeFundsReceiver(address payable _newReceiver)
        public
        onlyOwners()
        whenNotPaused()
    {
        _fundsReceiver = _newReceiver;
    }

    /*
    @dev Changes address for the Core contract
    @param _newAddress new Core contract address.
    */
    function changeCoreAddress(InterfaceCore _newAddress)
        external
        onlyOwners()
        whenNotPaused()
    {
        _core = _newAddress;
    }
}

interface InterfaceCore {
    function mintCustomHorse(
        address _owner,
        uint256 _genotype,
        bytes32 _gender,
        bytes32 _name,
        bytes32 _color
    ) external;
}
