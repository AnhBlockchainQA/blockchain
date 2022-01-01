// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

/**
@title WinningsWatcher
@author The VHS team
 */
contract WinningsWatcher is Context {
    using SafeERC20 for IERC20;

    IERC20 private _weth;

    constructor(IERC20 weth_) {
        _weth = weth_;
    }

    mapping(bytes32 => mapping(uint256 => mapping(address => bool))) private _isUserPaid;

    event WinningsTransfer(bytes32 indexed _raceId, address _payee, uint256 _horseId, uint256 _amountPaid);

    /**
    @notice Sends winnings from sender to payee
    @param _raceId ID of the race to be paid
    @param _payee Address of user receiving winnings
    @param _horseId The horse this user is being paid for
    @param _amountToPay Amount to pay to user
     */
    function sendWinnings(
        bytes32 _raceId,
        address _payee,
        uint256 _horseId,
        uint256 _amountToPay
    ) external {
        require(!_isUserPaid[_raceId][_horseId][_payee], "WinningsWatcher: user has been paid already");

        _isUserPaid[_raceId][_horseId][_payee] = true;

        _weth.safeTransferFrom(_msgSender(), _payee, _amountToPay);

        emit WinningsTransfer(_raceId, _payee, _horseId, _amountToPay);
    }

    /**
    @notice Returns whether or not an user has been paid for a race
    @param _raceId ID of the race
    @param _horseId ID of the horse
    @param _user Address of user to check
    @return bool indicating whether or not the user was paid
     */
    function isUserPaid(
        bytes32 _raceId,
        uint256 _horseId,
        address _user
    ) external view returns (bool) {
        return _isUserPaid[_raceId][_horseId][_user];
    }

    /**
    @notice Returns ERC20 (WETH) address
    @return Address indicating WETH's contract address
     */
    function getWethAddress() external view returns (address) {
        return address(_weth);
    }
}
