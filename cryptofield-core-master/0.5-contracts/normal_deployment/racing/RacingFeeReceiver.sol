pragma solidity ^0.5.8;

import "./RacingAdmins.sol";

contract RacingFeeReceiver is RacingAdmins {
    address payable private _feeWallet;

    event FeeWalletTransferred(address indexed previousFeeWallet, address indexed newFeeWallet);

    /**
     * @dev Returns the address of the current fee receiver.
     */
    function feeWallet() public view returns (address payable) {
        return _feeWallet;
    }

    /**
     * @dev Throws if called by any account other than the fee receiver wallet.
     */
    modifier onlyFeeWallet() {
        require(isFeeWallet(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current fee receiver wallet.
     */
    function isFeeWallet() public view returns (bool) {
        return _msgSender() == _feeWallet;
    }

    /**
     * @dev Leaves the contract without fee receiver wallet.
     *
     * NOTE: Renouncing will leave the contract without an fee receiver wallet.
     * It means that fee will be transferred to the zero address.
     */
    function renounceFeeWallet() public onlyAdmin {
        emit FeeWalletTransferred(_feeWallet, address(0));
        _feeWallet = address(0);
    }

    /**
     * @dev Transfers address of the fee receiver to a new address (`newFeeWallet`).
     * Can only be called by admins.
     */
    function transferFeeWalletOwnership(address payable newFeeWallet) public onlyAdmin {
        _transferFeeWalletOwnership(newFeeWallet);
    }

    /**
     * @dev Transfers address of the fee receiver to a new address (`newFeeWallet`).
     */
    function _transferFeeWalletOwnership(address payable newFeeWallet) internal {
        require(newFeeWallet != address(0), "Ownable: new owner is the zero address");
        emit FeeWalletTransferred(_feeWallet, newFeeWallet);
        _feeWallet = newFeeWallet;
    }
}