pragma solidity ^0.5.8;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./RacingFeeReceiver.sol";
import "../IERC20.sol";

contract RacingStorage is RacingFeeReceiver, ReentrancyGuard {
    // --
    // Permanent Storage Variables
    // --

    mapping(bytes32 => Race) public Races; // The race mapping structure.
    mapping(uint256 => uint256) public Horse_Active_Races; // Number of races the horse is registered for.
    mapping(bytes32 => bool) public ID_Saved; // Returns whether or not the race ID is present on storage already.
    mapping(uint256 => uint256) public Position_To_Payment; // Returns the percentage of the payment depending on horse's position in a race.
    mapping(address => bool) public Is_Authorized; // Returns whether an address is authorized or not.
    mapping(bytes32 => string) public Cancelled_Races; // Returns a cancelled race and its reason to be cancelled.
    mapping(bytes32 => bool) public Has_Zed_Claimed; // Returns whether or not winnings for a race have been claimed for Zed.

    address BB; // Blockchain Brain

    IERC20 weth; // WETH contract

    struct Race {
        string Track_Name; // Name of the track or event.
        bytes32 Race_ID; // Key provided for Race ID.
        uint256 Length; // Length of the track (m).
        uint256 Horses_Registered; // Current number of horses registered.
        uint256 Entrance_Fee; // Entrance fee for a particular race (10^18).
        uint256 Prize_Pool; // Total bets in the prize pool (10^18).
        uint256 Horses_Allowed; // Total number of horses allowed for a race.
        uint256[] Horses; // List of Horse IDs on Race.
        State Race_State; // Current state of the race.
        mapping(uint256 => Horse) Lineup; // Mapping of the Horse ID => Horse struct.
        mapping(uint256 => uint256) Gate_To_ID; // Mapping of the Gate # => Horse ID.
        mapping(uint256 => bool) Is_Gate_Taken; // Whether or not a gate number has been taken.
    }

    struct Horse {
        uint256 Gate; // Gate this horse is currently at.
        uint256 Total_Bet; // Total amount bet on this horse.
        uint256 Final_Position; // Final position of the horse (1 to Horses allowed in race).
        address Horse_Owner;  // The address who nominated this horse
        mapping(address => uint256) Bet_Placed; // Amount a specific address bet on this horse.
    }

    enum State {Null, Registration, Betting, Final, Fail_Safe}
}
