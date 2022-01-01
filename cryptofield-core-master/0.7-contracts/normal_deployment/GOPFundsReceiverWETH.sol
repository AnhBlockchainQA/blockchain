// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./EIP712MetaTransaction.sol";

/**
@title ZED WETH Funds Receiver
@author The VHS team
*/
contract GOPFundsReceiverWETH is
    Pausable,
    AccessControl,
    EIP712MetaTransaction
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 internal weth; // WETH contract
    InterfaceCore private _core;
    address private _fundsReceiver;

    bytes32 public constant GOP_OWNERS_ROLE = bytes32("gfr_owners");
    bytes32 public constant GOP_OWNERS_ADMIN_ROLE = bytes32("gfr_owners_admin");

    mapping(bytes32 => bool) internal isCodeUsed; // Mapping for horse codes and check their availability.

    event ReceivedGOPFunds(
        address indexed _buyer,
        uint256 _paidAmount,
        bytes32 indexed _horseCode
    );

    event CodeStatusChanged(bytes32 indexed _horseCode, bool _codeStatus);

    constructor(
        address fundsReceiver_,
        InterfaceCore core_,
        IERC20 _weth
    ) {
        _fundsReceiver = fundsReceiver_;
        weth = _weth;
        _core = core_;


        // Access Control
        _setRoleAdmin(GOP_OWNERS_ROLE, GOP_OWNERS_ADMIN_ROLE);

        _setupRole(GOP_OWNERS_ADMIN_ROLE, _msgSender());
    }

    modifier onlyOwners() {
        require(hasRole(GOP_OWNERS_ROLE, _msgSender()), "GOP: Unauthorized");
        _;
    }

    /*
    @dev Receives funds for a horse buy and emits an event to be catched by our event handler.
    @dev Sends '_horseCode' and '_horsePrice' which will be handled by the back-end.
    */
    function receiveGOPFunds(bytes32 _horseCode, uint256 _horsePrice, bytes32 _horseName )
        external
        whenNotPaused()
    {
        require(_horseCode != '', "GOP: Code cannot be an empty string");
        require(_horsePrice != 0, "GOP: Price cannot be 0");
        require(!isCodeUsed[_horseCode], "GOP: Code has already been used");
        require(!_core.isNameTaken(_horseName), "Core: name already taken");

        isCodeUsed[_horseCode] = true;

        weth.safeTransferFrom(_msgSender(), _fundsReceiver, _horsePrice);
        emit ReceivedGOPFunds(_msgSender(), _horsePrice, _horseCode);
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

    receive() external payable {}

    /*  GETTER FUNCS    */

    /**
     * @dev Returns true if the caller is the current fee receiver wallet.
     */
    function isFundsReceiver() public view returns (bool) {
        return _msgSender() == _fundsReceiver;
    }


    /*  RESTRICTED FUNCS    */
    /*
    @dev Changes the address that's receiving funds from sells
    @param _newReceiver new admin address that's receiving funds
    */
    function changeFundsReceiver(address _newReceiver)
        public
        onlyOwners()
        whenNotPaused()
    {
        _fundsReceiver = _newReceiver;
    }

    function _msgSender() internal view override returns (address payable sender) {
        sender = msgSender();
    }

    /**
    @notice Pauses contract
     */
    function pause() external onlyOwners() {
        _pause();
    }

    /**
    @notice Unpauses the contract
     */
    function unpause() external onlyOwners() {
        _unpause();
    }
}

interface InterfaceCore {
    function isNameTaken(bytes32 _horseName) external view returns (bool);
}