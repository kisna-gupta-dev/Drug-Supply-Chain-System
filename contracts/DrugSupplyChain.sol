//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink\contracts\src\v0.8\automation\interfaces\AutomationCompatibleInterface.sol";
import {Escrow} from "./Escrow.sol";

/**
 * @title DrugSupplyChain
 *
 * @dev This contract manages the drug supply chain, allowing manufacturers, distributors, and retailers to
 * create batches, handle returns, and manage roles.
 * It uses Chainlink for price feeds and automation for handling return requests.
 * It implements role-based access control using OpenZeppelin's AccessControl.
 * The contract allows for batch creation, purchase by distributors and retailers, return requests,
 * and approval of return requests.
 * It also includes functionality for reselling batches and managing addresses.
 * The contract emits events for significant actions such as batch creation, purchases, return requests,
 * and role management.
 * It ensures that only authorized roles can perform specific actions, and it provides mechanisms
 * to freeze and unfreeze addresses to prevent unauthorized actions.
 * The contract is designed to be secure, with checks for valid addresses, batch ownership, and
 * appropriate status checks before allowing actions like reselling or returning batches.
 * The contract is designed to ensure the integrity and authenticity of drugs in the supply chain.
 *
 * @author Kisna Gupta
 *
 * @notice This contract is part of a larger drug supply chain system and should be used in conjunction with other contracts
 * in the system for full functionality.
 */
contract DrugSupplyChain is AccessControl, AutomationCompatibleInterface {
    //The contract is for tracking Supply Chain system of Drugs
    //To ensure the integrity and authenticity of drugs in the supply chain

    /// @notice Role identifier for manufacturers in the supply chain
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    /// @notice Role identifier for distributors in the supply chain
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    /// @notice Role identifier for retailers in the supply chain
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    //mappings
    ///@notice Counter for batches created by each manufacturer
    mapping(address => uint256) public batchCounter;

    /// @notice Mapping from batch ID to Batch details
    mapping(bytes32 => Batch) public batchIdToBatch;

    /// @notice Mapping to check if an address is frozen
    mapping(address => bool) public isFrozen;

    /// @notice Mapping to track return requests for batches
    mapping(bytes32 => ReturnRequest) public returnRequests;

    /// @notice Array to store pending return requests
    ReturnRequest[] public pendingRequests;

    /// @notice Counter for the number of batches created
    uint256 public batchCount;

    /// @notice Chainlink price feed for USD to ETH conversion
    AggregatorV3Interface internal dataFeed;
    /// @notice Escrow contract to handle payments securely
    Escrow public escrowContract;

    //Enum for Batch Status External
    enum BatchStatus {
        Manufactured,
        OwnedByDistributor,
        ReadyToSellToRetailer,
        OwnedByRetailer,
        ReturnRequestedByRetailer,
        ReturnRequestedByDistributor,
        ReturnedToDistributor,
        ReturnedToManufacturer,
        ResellingToDistributor
    }
    //Structures
    struct Batch {
        bytes32 batchId;
        string drugName;
        uint256 productQuantity;
        uint256 drugQuantity; //Quantity of the drug in the batch
        address manufacturer;
        address distributor;
        address retailer;
        uint256 expiryDate;
        string status; //e.g. "Manufactured(Manufacturer has it)", "Distributed(Distributer has it)", "Delivered to Retail"
        uint256 timestamp; //Timestamp of the last update
        uint256 price; //Price of the drug in the batch
        uint256 productPrice;
        BatchStatus statusEnum;
        uint256 mrp; //Maximum Retail Price
    }

    struct ReturnRequest {
        bytes32 batchId;
        uint256 timestamp;
        address requester;
        bool refunded;
        bool approved;
        string reason;
    }

    //Events
    /// @notice Event emitted when a new batch is created
    /// @param batchId The unique identifier for the batch
    /// @param statusEnum The status of the batch
    /// @param drugName The name of the drug in the batch
    /// @param productQuantity The quantity of the product in the batch
    /// @param drugQuantity The quantity of the drug in the batch
    /// @param manufacturer The address of the manufacturer who created the batch
    /// @param expiryDate The expiry date of the drug in the batch
    /// @param price The price of the drug in the batch
    /// @param status The status of the batch
    /// @param timestamp The timestamp when the batch was created
    /// @param mrp The maximum retail price of the drug in the batch
    event BatchCreated(
        bytes32 indexed batchId,
        BatchStatus statusEnum,
        string drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address indexed manufacturer,
        uint256 expiryDate,
        uint256 price,
        string status,
        uint256 timestamp,
        uint256 mrp
    );

    /// @notice Event emitted when a distributor purchases a batch
    /// @param batchId The unique identifier for the batch
    /// @param statusEnum The status of the batch
    /// @param drugName The name of the drug in the batch
    /// @param productQuantity The quantity of the product in the batch
    /// @param drugQuantity The quantity of the drug in the batch
    /// @param manufacturer The address of the manufacturer who created the batch
    /// @param expiryDate The expiry date of the drug in the batch
    /// @param price The price of the drug in the batch
    /// @param status The status of the batch
    /// @param timestamp The timestamp when the batch was created
    /// @param mrp The maximum retail price of the drug in the batch
    event DistributerPurchased(
        bytes32 indexed batchId,
        BatchStatus statusEnum,
        string drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address indexed manufacturer,
        address indexed distributor,
        uint256 expiryDate,
        uint256 price,
        string status,
        uint256 timestamp,
        uint256 mrp
    );

    /// @notice Event emitted when a retailer purchases a batch
    event RetailerPurchased(
        bytes32 indexed batchId,
        BatchStatus statusEnum,
        string drugName,
        uint256 productQuantity,
        address indexed manufacturer,
        address indexed distributor,
        address retailer,
        uint256 expiryDate,
        uint256 productPrice,
        string status,
        uint256 timestamp,
        uint256 mrp
    );

    /// @notice Event emitted when a batch is eligible for reselling
    /// @param reason The reason for reselling the batch
    event EligibleForResell(
        bytes32 indexed batchId,
        BatchStatus statusEnum,
        string drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address indexed manufacturer,
        address indexed distributor,
        uint256 expiryDate,
        uint256 price,
        string status,
        uint256 timestamp,
        uint256 mrp,
        string reason
    );

    /// @notice Event emitted when a batch is resold
    event ResellingDone(
        bytes32 indexed batchId,
        BatchStatus statusEnum,
        string drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address indexed manufacturer,
        address indexed distributor,
        uint256 expiryDate,
        uint256 price,
        string status,
        uint256 timestamp,
        uint256 mrp
    );

    /// @notice Event emitted when a return request is made
    /// @param batchId The unique identifier for the batch
    /// @param requester The address of the requester (retailer or distributor)
    /// @param reason The reason for the return request
    /// @param approved Whether the request is approved
    /// @param timestamp The timestamp when the request was made
    /// @param refunded Whether the request has been refunded
    event ReturnRequested(
        bytes32 indexed batchId,
        uint256 indexed timestamp,
        address indexed requester,
        bool indexed approved,
        bool indexed refunded,
        string reason
    );

    /// @notice Event emitted when a return request is approved
    event RequestApproved(
        bytes32 indexed batchId,
        address indexed requester,
        uint256 indexed timestamp,
        bool indexed approved,
        bool indexed refunded,
        string reason
    );

    /// @notice Event emitted when an address is frozen
    /// @param account The account address needs to be frozen
    event AddressFrozen(address account);
    /// @notice Event emitted when an address is unfrozen
    /// @param account The account address needs to be unfreeze
    event AddressUnfrozen(address account);

    //errors
    error AddressAlreadyExists(string role, address account);
    error AddressInvalid(address account);
    error InvalidAmount(_usdAmount);
    //Modifiers
    /// @notice Modifier to check if the newAddress is not already a member of any role
    /// @param newMember The address to check if it is already a member of any role
    modifier mustBeNew(address newMember) {
        if (hasRole(MANUFACTURER_ROLE, newMember)) {
            revert AddressAlreadyExists("Manufacturer", newMember);
        }
        if (hasRole(RETAILER_ROLE, newMember)) {
            revert AddressAlreadyExists("Retailer", newMember);
        }
        if (hasRole(DISTRIBUTOR_ROLE, newMember)) {
            revert AddressAlreadyExists("Distributor", newMember);
        }
        if (newMember == address(0)) {
            AddressInvalid(newMember);
        }
        _;
    }

    modifier notFrozen() {
        if (isFrozen[msg.sender]) {
            revert AddressInvalid(msg.sender);
        }
        _;
    }

    /// @notice Constructor to set the deployer as the DEFAULT_ADMIN_ROLE and to set priceFeed
    /// @param _priceFeedAddress The address of price feed for ETH conversion
    constructor(address _priceFeedAddress) {
        dataFeed = AggregatorV3Interface(_priceFeedAddress);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice ChainLink automation function (This is used to check if any request is pending for approval for more than 3 days)
    /// @notice CheckUpKeeps checks the condition (here for 3 days)
    /// @param checkData The data sent for checking data
    /// @return upkeepNeeded Whether upkeep is needed
    /// @return performData The data to be sent for performing upkeep
    function checkUpkeep(
        bytes calldata checkData
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        for (uint256 i = 0; i < pendingRequests.length; i++) {
            ReturnRequest memory request = pendingRequests[i];

            if (
                block.timestamp - request.timestamp > 3 days &&
                !request.approved &&
                !request.refunded
            ) {
                upkeepNeeded = true;
                performData = abi.encode(request.batchId);
                return (upkeepNeeded, performData);
            }
        }
        return (false, "");
    }

    /// @notice PerformUpkeep performs the operations instructed in it after CheckUpkeep's instructions are checked
    /// @param performData The data sent from CheckUpKeep
    function performUpkeep(bytes calldata performData) external override {
        bytes32 batchId = abi.decode(performData, (bytes32));
        if (returnRequests[batchId].requester == address(0)) {
            revert AddressInvalid(batchIdToBatch[batchId].retailer);
        }
        if (hasRole(DISTRIBUTOR_ROLE, returnRequests[batchId].requester)) {
            escrowContract.release(
                returnRequests[batchId].requester,
                batchIdToBatch[batchId].productPrice
            );
        } else {
            escrowContract.release(
                returnRequests[batchId].requester,
                batchIdToBatch[batchId].price
            );
        }
        returnRequests[batchId].approved = true;
        returnRequests[batchId].refunded = true;
        batchIdToBatch[batchId].statusEnum = BatchStatus.ReturnedToManufacturer;
    }

    /// @notice The function for price Conversion rate
    /// @dev This function fetches the latest price from the Chainlink data feed
    /// @return The latest price of ETH in USD
    function getDataFeedLatestAnswer() internal view returns (uint256) {
        (
            ,
            /* uint80 roundId */ int256 answer /*uint256 startedAt*/ /*uint256 updatedAt*/ /*uint80 answeredInRound*/,
            ,
            ,

        ) = dataFeed.latestRoundData();
        return uint256(answer);
    }

    /** @notice The Eth to USD calculation
     * @dev //IMPORTANT -> THE _usdAMount PASSED MUST BE MULTIPLIESD BY 1e18
     *A very important function to be called for calculating Ethereum from USD entered
     *The function will be first called before any payment is initiated
     *As the inputs are in USD and the transactions are done in eth so we need to convert that USD in Eth
     *First we will convert USD in ETh then we call any other function
     * @param _usdAmount the Amount to be transferred in USD
     * @return amountEth the amount in Eth that needs to be transferred
     */
    function calculateEthfromUSD(
        uint256 _usdAmount
    ) internal returns (uint256) {
        uint256 price = getDataFeedLatestAnswer();
        if (price <= 0) {
            revert("Invalid price feed data");
        }
        if (_usdAmount <= 0) {
            revert InvalidAmount(_usdAmount);
        }

        uint256 amountEth = (_usdAmount * 1e8) / price;
        return amountEth;
    }

    /// @notice function to withdraw stcked eth from contract
    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        escrowContract.release(msg.sender, address(this).balance);
    }

    /// @notice Rvoking Manufacturer Role, Only DEFAULT_ADMIN_ROLE can remove Manufacturer roles
    /// @param manufacturer Address of manufacturer to revoke role
    function removeManufacturer(
        address manufacturer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MANUFACTURER_ROLE, manufacturer);
    }

    /// @notice Revoking distributor Role, Only DEFAULT_ADMIN_ROLE can remove Manufacturer roles
    /// @param distributor Address of distributor to revoke role
    function removeDistributor(
        address distributor
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DISTRIBUTOR_ROLE, distributor);
    }

    /// @notice Revoking retailer Role, Only DEFAULT_ADMIN_ROLE can remove Manufacturer roles
    /// @param retailer Address of retailer to revoke role
    function removeRetailer(
        address retailer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(RETAILER_ROLE, retailer);
    }
}
