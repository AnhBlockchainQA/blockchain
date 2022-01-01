pragma solidity ^0.5.8;

import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./RacingStorage.sol";
import "../EIP712MetaTransaction.sol";
import "../SafeERC20.sol";


contract RacingArena is RacingStorage, Pausable, EIP712MetaTransaction {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // -----------------------------------------
    // EVENTS
    // -----------------------------------------

    event BetPlaced(
        bytes32 indexed _raceId,
        address indexed _bettor,
        uint256 _betAmount,
        uint256 indexed _horseID
    );

    event PrizeClaimed(
        bytes32 indexed _raceId,
        address indexed _bettor,
        uint256 _claimAmount,
        uint256 indexed _horseID
    );

    event HorseRegistered(
        bytes32 indexed _raceId,
        address indexed _horseOwner,
        uint256 indexed _horseID,
        uint256 _gateNumber
    );

    event RaceCreated(
        bytes32 indexed _raceId,
        string _name,
        uint256 _length,
        uint256 _registrationFee
    );

    event RaceFull(bytes32 indexed _raceId);

    event ResultsPosted(
        bytes32 indexed _raceId,
        uint256 _firstPlaceHorseID,
        uint256 _secondPlaceHorseID,
        uint256 _thirdPlaceHorseID
    );

    event RaceCancelled(
        bytes32 indexed _raceId,
        string _reason,
        address _canceller
    );

    modifier onlyBB {
        require(msg.sender == BB, "onlyBB: unauthorized address");
        _;
    }

    modifier adminOrBB {
        require(_msgSender() == BB || isAdmin(_msgSender()), "adminOrBB: unauthorized");
        _;
    }

    // This acts as the constructor
    function initSetup(address _bb, IERC20 _weth) public onlyAdmin() {
      Position_To_Payment[1] = 60;
      Position_To_Payment[2] = 20;
      Position_To_Payment[3] = 10;

      BB = _bb;
      weth = _weth;
    }

    // -----------------------------------------
    // FALLBACK
    // -----------------------------------------

    function() external payable {}

    // -----------------------------------------
    // SETTERS (Only Admin/BB)
    // -----------------------------------------

    /**
     * @dev Admin creates upcoming races, specifying the track name, the track length, and the entrance fee.
     */
    function createRace(
        bytes32 _raceId,
        string calldata _name,
        uint256 _horsesAllowed,
        uint256 _entranceFee,
        uint256 _length
    )
        external
        adminOrBB()
        nonReentrant()
        whenNotPaused()
    {
        // Pre-check and struct initialization.
        require(_entranceFee > 0, "Entrance fee lower than zero");
        require(!ID_Saved[_raceId], "Race ID exists");

        Race memory race;
        race.Track_Name = _name;
        race.Race_ID = _raceId;
        race.Length = _length;
        race.Entrance_Fee = _entranceFee;
        race.Horses_Allowed = _horsesAllowed;
        race.Race_State = State.Registration;

        Races[_raceId] = race;
        ID_Saved[_raceId] = true;

        // Event trigger.
        emit RaceCreated(_raceId, _name, _length, _entranceFee);
    }

    function deregisterHorseFromRace(
        uint256 _horseID,
        bytes32 _raceID,
        address horseOwner
    )
        external
        onlyBB()
    {
        Race storage race = Races[_raceID];

        // Default validations
        require(
            race.Lineup[_horseID].Gate != 0,
            "Horse is not registered for this race"
        );
        require(
            race.Race_State == State.Registration,
            "BB can only remove a horse from a race in registration stage"
        );

        uint256 fee = race.Entrance_Fee;
        uint256 horseGateNumber = race.Lineup[_horseID].Gate;

        // Decrease horse active races count
        Horse_Active_Races[_horseID]--;

        // Decrease registered horses amount
        race.Horses_Registered--;

        // Clean horse values of lineup
        race.Lineup[_horseID] = Horse(0, 0, 0, address(0));

        // Clean gate from horse id
        race.Gate_To_ID[horseGateNumber] = 0;

        // Mark gate number as empty again
        race.Is_Gate_Taken[horseGateNumber] = false;

        // Decrease prize pool amount
        race.Prize_Pool -= fee;

        // Decrease horse total bet amount
        race.Lineup[_horseID].Total_Bet -= fee;

        // Decrease horse owner total bet amount
        race.Lineup[_horseID].Bet_Placed[horseOwner] -= fee;

        // Remove horse from registered horses array
        _deleteHorseFromHorsesArray(_horseID, _raceID);

        // Confiscate fee and send to fee wallet address
        weth.safeTransfer(feeWallet(), fee);
    }

    /**
     * Admin posts the result of the race, enabling bettors to claim their winnings.
     * @param _raceId Race ID we're going to post the results to.
     * @param _results List of of horse IDs that participated on the race in position order.
     * @dev Receives results for a given race, removes 1 active race from the given horses.
     * Transitions race state and sends funds to one of the owner addresses as well.
     */
    function postResults(
        bytes32 _raceId,
        uint256[12] calldata _results
    )
        external
        adminOrBB()
        nonReentrant()
    {
        Race storage race = Races[_raceId];

        // Pre-checks
        require(
            race.Race_State == State.Betting || race.Race_State == State.Registration,
            "Race is not on registration state"
        );

        // State transition to 'Final'
        race.Race_State = State.Final;

        // Update the Race struct, active race reduced.
        for (uint256 i = 0; i < race.Horses_Allowed; i++) {
            uint256 horseId = _results[i];
            uint256 horsePosition = i + 1;

            require(race.Lineup[horseId].Gate != 0, "ID not registered");

            race.Lineup[horseId].Final_Position = horsePosition;
            Horse_Active_Races[horseId]--;

            if (i < 3) {
                address horseOwner = race.Lineup[horseId].Horse_Owner;
                uint256 wonAmount = race.Prize_Pool.mul(Position_To_Payment[horsePosition]).div(100);

                // Transfer funds to winner
                weth.safeTransfer(horseOwner, wonAmount);

                emit PrizeClaimed(_raceId, horseOwner, wonAmount, horseId);
            }
        }

        // Transfer funds to one of Zed's accounts.
        weth.safeTransfer(feeWallet(), race.Prize_Pool.mul(10).div(100));

        emit ResultsPosted(_raceId, _results[0], _results[1], _results[2]);
    }

    function cancelRace(
        bytes32 _raceId,
        string calldata _reason
    )
        external
        onlyAdmin()
        nonReentrant()
    {
        Race storage race = Races[_raceId];

        // Pre-checks
        require(
            race.Race_State == State.Registration || race.Race_State == State.Betting,
            "Race is not on registration or betting state"
        );

        race.Race_State = State.Fail_Safe;
        Cancelled_Races[_raceId] = _reason;

        // Loops through the IDs on a race by index and removes them out of an active race.
        for (uint256 i = 0; i < race.Horses_Registered; i++) {
            Horse_Active_Races[race.Horses[i]]--;
        }

        emit RaceCancelled(_raceId, _reason, msg.sender);
    }

    function changePaymentAllocation(
        uint256 _position,
        uint256 _percentage
    )
        external
        onlyAdmin()
    {
        Position_To_Payment[_position] = _percentage;
    }

    // -----------------------------------------
    // SETTERS (Public)
    // -----------------------------------------

    /**
     * @dev Registers a horse for the selected race. Enacts transfer of the entrance fee, and transfer of the ERC-721 horse.
     */
    function registerHorse(
        bytes32 _raceId,
        uint256 _horseID,
        uint256 _gateNumber
    )
        external
        nonReentrant()
        whenNotPaused()
    {
        Race storage race = Races[_raceId];

        // Pre-checks.
        require(race.Race_State == State.Registration, "Race not accepting registrations");
        require(race.Horses_Registered < race.Horses_Allowed, "Max number of horses for race");
        require(_gateNumber >= 1, "Gate number lower than 1.");
        require(_gateNumber <= race.Horses_Allowed, "Gate number greater than max");
        require(!race.Is_Gate_Taken[_gateNumber], "Gate number already taken");
        require(Horse_Active_Races[_horseID] < 3, "Horse currently active in 3 races");
        require(race.Lineup[_horseID].Gate == 0, "Horse already registered for this race");

        // Transfer tokens from user wallet to racing arena contract
        weth.safeTransferFrom(msgSender(), address(this), race.Entrance_Fee);

        // Insert a new Horse struct with the appropriate information.
        Horse_Active_Races[_horseID]++;
        race.Horses_Registered++;
        race.Lineup[_horseID] = Horse(_gateNumber, 0, 0, msgSender());
        race.Gate_To_ID[_gateNumber] = _horseID;

        // Mark gate number as taken.
        race.Is_Gate_Taken[_gateNumber] = true;

        // Handle accounting of the registration fee as a bet on their horse.
        race.Prize_Pool += race.Entrance_Fee;
        race.Lineup[_horseID].Total_Bet += race.Entrance_Fee;
        race.Lineup[_horseID].Bet_Placed[msgSender()] += race.Entrance_Fee;
        race.Horses.push(_horseID);

        if (race.Horses_Registered == race.Horses_Allowed) {
            emit RaceFull(_raceId);
        }

        emit HorseRegistered(_raceId, msgSender(), _horseID, _gateNumber);
    }

    // -----------------------------------------
    // GETTERS
    // -----------------------------------------

    /**
     * @dev Small helper function for retrieving the Horse ID based off Gate # (1 - 12, no 0 element).
     */
    function getHorseID(bytes32 _raceId, uint256 _gate)
        external
        view
        returns (uint256)
    {
        return Races[_raceId].Gate_To_ID[_gate];
    }

    /**
     * @dev Small helper function for retrieving more detailed information about a horse (for Retrieval purposes) based off Gate # (1 - 12, no 0 element).
     */
    function getHorseInfo(bytes32 _raceId, uint256 _gate)
        external
        view
        returns (uint256, uint256)
    {
        Race storage race = Races[_raceId];

        return (
            race.Gate_To_ID[_gate],
            race.Lineup[race.Gate_To_ID[_gate]].Final_Position
        );
    }

    // Small helper function for personal bet information based off Gate # (1 - 12, no 0 element).
    function getBetInfo(
        bytes32 _raceId,
        uint256 _gate,
        address _bettor
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        Race storage race = Races[_raceId];

        return (
            race.Prize_Pool,
            race.Lineup[race.Gate_To_ID[_gate]].Total_Bet,
            race.Lineup[race.Gate_To_ID[_gate]].Bet_Placed[_bettor],
            race.Lineup[race.Gate_To_ID[_gate]].Final_Position
        );
    }

    function getHorsesInRace(bytes32 _raceId)
        external
        view
        returns (uint256[] memory)
    {
        Race memory race = Races[_raceId];

        return race.Horses;
    }

    function getBBAddress() external view returns (address) {
        return BB;
    }

    function getWethAddress() external view returns (IERC20) {
        return weth;
    }


    // -----------------------------------------
    // PRIVATE / INTERNAL
    // -----------------------------------------

    function _deleteHorseFromHorsesArray(
        uint256 _horseID,
        bytes32 _raceID
    )
        private
    {
        uint256 horseOrder = 0;
        uint256[] storage raceHorses = Races[_raceID].Horses;

        while (raceHorses[horseOrder] != _horseID) {
            horseOrder++;
        }

        uint256 raceHorsesLength = raceHorses.length;

        while (horseOrder < raceHorsesLength - 1) {
            raceHorses[horseOrder] = raceHorses[horseOrder + 1];
            horseOrder++;
        }

        raceHorses.length--;
    }
}
