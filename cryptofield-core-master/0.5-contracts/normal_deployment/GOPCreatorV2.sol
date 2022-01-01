pragma solidity ^0.5.8;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

contract GOPCreatorV2 is Ownable, Pausable {
    using SafeMath for uint256;

    address payable fundsReceiver;

    address oldGopAddress;
    address public core;
    address public blockchainBrain;

    bool anyBatchOpen;

    uint256 currentOpenBatch;

    mapping(uint256 => uint256) internal horsesForGen; // Saves amount of horses for specific genotype.
    mapping(uint256 => uint256) internal batchPrice; // Saves price for each batch in Ether.
    mapping(bytes32 => bool) internal isCodeUsed; // Mapping for horse codes and check their availability.

    event ReceivedGOPFunds(
        address indexed _buyer,
        uint256 _paidAmount,
        bytes32 indexed _horseCode
    );

    event CodeStatusChanged(bytes32 indexed _horseCode, bool _codeStatus);

    constructor(
        address payable _fundsReceiver,
        address _oldGopAddr,
        address _coreAddr,
        address _bb
    ) public {
        oldGopAddress = _oldGopAddr;
        core = _coreAddr;
        fundsReceiver = _fundsReceiver;
        blockchainBrain = _bb;

        // Get remaining horses for each batch from old contract so we have the same state.
        horsesForGen[1] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            1
        );
        horsesForGen[2] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            2
        );
        horsesForGen[3] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            3
        );
        horsesForGen[4] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            4
        );
        horsesForGen[5] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            5
        );
        horsesForGen[6] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            6
        );
        horsesForGen[7] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            7
        );
        horsesForGen[8] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            8
        );
        horsesForGen[9] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            9
        );
        horsesForGen[10] = InterfaceGOPCreatorV1(oldGopAddress).horsesRemaining(
            10
        );

        batchPrice[1] = 0.40 ether;
        batchPrice[2] = 0.30 ether;
        batchPrice[3] = 0.25 ether;
        batchPrice[4] = 0.20 ether;
        batchPrice[5] = 0.185 ether;
        batchPrice[6] = 0.18 ether;
        batchPrice[7] = 0.175 ether;
        batchPrice[8] = 0.17 ether;
        batchPrice[9] = 0.165 ether;
        batchPrice[10] = 0.16 ether;
    }

    modifier onlyAuthorizedAddresses() {
        require(
            msg.sender == owner() || msg.sender == blockchainBrain,
            "Unauthorized"
        );
        _;
    }

    /*
    @dev Manually opens a batch of horses.
    @param _batch Batch to open between 1 and 10
    */
    function openBatch(uint256 _batch) external onlyOwner() {
        // require(!anyBatchOpen, "A batch is already open");
        require(_batch >= 1 && _batch <= 10, "Gen not recognized");

        closeBatch();

        anyBatchOpen = true;
        currentOpenBatch = _batch;
    }

    /*
    @dev Closes a the current open batch, we only allow one batch open at a time.
    */
    function closeBatch() public onlyOwner() {
        anyBatchOpen = false;
        currentOpenBatch = 0;
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
        require(!isCodeUsed[_horseCode], "Code has already been used");

        isCodeUsed[_horseCode] = true;

        fundsReceiver.transfer(msg.value);

        emit ReceivedGOPFunds(msg.sender, msg.value, _horseCode);
    }

    /*
    @dev Marks a code as used.
    @param _horseCode code we're marking as used
    */
    function markCodeAsUsed(bytes32 _horseCode)
        external
        onlyAuthorizedAddresses()
    {
        require(!isCodeUsed[_horseCode], "Code has been used");

        isCodeUsed[_horseCode] = true;

        emit CodeStatusChanged(_horseCode, true);
    }

    /*
    @dev Marks a code as unused.
    @param _horseCode code we're marking as unused
    */
    function markCodeAsUnused(bytes32 _horseCode)
        external
        onlyAuthorizedAddresses()
    {
        // Code must be used already before setting state back to false.
        require(isCodeUsed[_horseCode], "Code has not been used");

        isCodeUsed[_horseCode] = false;

        emit CodeStatusChanged(_horseCode, false);
    }

    /*
    @dev  Creates a horse based on batch open.
    @param _owner Address that's getting the horse.
    @param _hash Hash that holds horse data.
    @return horse ID
    */
    function createGOP(address _owner, string calldata _hash)
        external
        payable
        whenNotPaused()
        returns (uint256)
    {
        require(anyBatchOpen, "No batch open");
        require(
            horsesForGen[currentOpenBatch] != 0,
            "Cap for specified genotype already met"
        );

        // We could have used a mapping for this instead but it wasn't initialized.
        uint256 amount = getPriceForBatch(currentOpenBatch);

        uint256 horseId = _saleHorse(_owner, _hash, amount);
        return horseId;
    }

    /*
    @dev Creates a custom horse from the specified params. Mostly for marketing purposes.
    @dev This horse also counts for the 38.000 horses that'll get released.
    @param _owner Address that's getting the horse.
    @param _hash Hash that holds horse data
    @param _batch Batch that acts as the genotype, should only be between 1 and 10.
    @param _gender Horse gender
    @return horse ID
    */
    function createCustomHorse(
        address _owner,
        string calldata _hash,
        uint256 _batch,
        bytes32 _gender
    ) external onlyAuthorizedAddresses() returns (uint256) {
        require(horsesForGen[_batch] != 0, "Limit for genotype reached");

        uint256 tokenId = InterfaceCore(core).mintCustomHorse(
            _owner,
            _hash,
            _batch,
            _gender
        );

        horsesForGen[_batch] = horsesForGen[_batch].sub(1);

        return tokenId;
    }

    /*
    @dev Creates a random horse for the given batch.
    @dev 'Random' in this context means that we won't decide the gender or other data.
    @param _owner Address that's getting the horse
    @param _hash Hash that holds horse data
    @param _batch Batch that acts as the genotype, can only be between 1 and 10.
    @return horse ID
    */
    function createRandomHorseFor(
        address _owner,
        string calldata _hash,
        uint256 _batch
    ) external onlyAuthorizedAddresses() returns (uint256) {
        require(horsesForGen[_batch] != 0, "Limit for genotype reached");
        uint256 tokenId = InterfaceCore(core).mintToken(_owner, _hash, _batch); // '_batch' is horse's genotype.

        horsesForGen[_batch] = horsesForGen[_batch].sub(1);

        return tokenId;
    }

    function() external payable {}

    /*  GETTERS */

    /*
    @param _gen genotype or batch
    @return amount of horses remaining
    */
    function horsesRemaining(uint256 _gen) public view returns (uint256) {
        return horsesForGen[_gen];
    }

    /*
    @return bool indicating if a batch is open
    @return which batch is open if any
    */
    function isABatchOpen() public view returns (bool, uint256) {
        return (anyBatchOpen, currentOpenBatch);
    }

    /*
    @param _batch Batch or genotype
    @return price from a given batch.
    */
    function getPriceForBatch(uint256 _batch) public view returns (uint256) {
        require(_batch >= 1 && _batch <= 10, "Batch out of bounds");

        return batchPrice[_batch];
    }

    /*
    @dev Gives owner a way to update prices for a batch. Useful when Ether price fluctuates too much.
    @param _batch Batch to modify the price for
    @param _newPrice new price to set
    */
    function modifyPriceForBatch(uint256 _batch, uint256 _newPrice)
        public
        onlyOwner()
    {
        batchPrice[_batch] = _newPrice;
    }

    /*  RESTRICTED FUNCS    */
    /*
    @dev Changes the address that's receiving funds from sells
    @param _newReceiver new admin address that's receiving funds
    */
    function changeFundsReceiver(address payable _newReceiver)
        public
        onlyOwner()
    {
        fundsReceiver = _newReceiver;
    }

    /*
    @dev Changes address for BlockchainBrain
    @param _newAddress new blockchain brain address.
    */
    function changeBBAddress(address _newAddress)
        external
        onlyOwner()
    {
        blockchainBrain = _newAddress;
    }

    /*  PRIVATE FUNCS   */

    /*
    @dev Does all the logic when selling a horse, checking the price, generating the token, etc...
    @param _owner Address that's receiving the horse
    @param _hash Hash that holds horse data
    @param _amount paid amount
    @return horse ID
    */
    function _saleHorse(address _owner, string memory _hash, uint256 _amount)
        private
        returns (uint256)
    {
        require(msg.value >= _amount, "Price not met");

        uint256 horseId = InterfaceCore(core).mintToken(
            _owner,
            _hash,
            currentOpenBatch
        );

        if (horseId == 0) return horseId;

        horsesForGen[currentOpenBatch] = horsesForGen[currentOpenBatch].sub(1);

        /*
        Check if we should close the batch automatically.
        This happens only once when a batch has sold 500 horses.
        You can re-open the batch again and the horses will sell depending on the batch open.
        */
        if (_shouldClose()) {
            closeBatch();
        }

        fundsReceiver.transfer(msg.value);

        return horseId;
    }

    /*
    @dev Checks whether or not a batch should close.
    */
    function _shouldClose() private view returns (bool) {
        if (currentOpenBatch >= 1 && currentOpenBatch <= 4)
            return horsesForGen[currentOpenBatch] == 500;
        if (currentOpenBatch == 5) return horsesForGen[5] == 1500;
        if (currentOpenBatch == 6) return horsesForGen[6] == 2500;
        if (currentOpenBatch == 7) return horsesForGen[7] == 3500;
        if (currentOpenBatch == 8) return horsesForGen[8] == 5500;
        if (currentOpenBatch == 9) return horsesForGen[9] == 8500;
        if (currentOpenBatch == 10) return horsesForGen[10] == 9500;
    }
}

// This is used entirely for testing as we need GOPCreatorV2 to communicate with an external contract
contract PrivateGOPCreatorV2 {
  mapping(uint256 => uint256) private _genToAmount;


  constructor() public {
    _genToAmount[1] = 1000;
    _genToAmount[2] = 1000;
    _genToAmount[3] = 1000;
    _genToAmount[4] = 1000;
    _genToAmount[5] = 1000;
    _genToAmount[6] = 1000;
    _genToAmount[7] = 1000;
    _genToAmount[8] = 1000;
    _genToAmount[9] = 1000;
    _genToAmount[10] = 10000;
  }

  function horsesRemaining(uint256 _gen) external view returns(uint256) {
    return _genToAmount[_gen];
  }
}

interface InterfaceGOPCreatorV1 {
    function horsesRemaining(uint256 _gen) external view returns (uint256);
}

interface InterfaceCore {
    function mintToken(
        address _owner,
        string calldata _hash,
        uint256 _batchNumber
    ) external payable returns (uint256);
    function mintCustomHorse(
        address _owner,
        string calldata _hash,
        uint256 _genotype,
        bytes32 _gender
    ) external returns (uint256);
}
