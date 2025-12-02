//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Escrow} from "./Escrow.sol";
import {HandlingAddresses} from "./HandlingAddresses.sol";

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

contract DrugSupplyChain is HandlingAddresses {
    //The contract is for tracking Supply Chain system of Drugs
    //To ensure the integrity and authenticity of drugs in the supply chain

    //mappings
    ///@notice Counter for batches created by each manufacturer
    mapping(address => uint256) public batchCounter;

    /// @notice Mapping from batch ID to Batch details
    mapping(bytes32 => Batch) public batchIdToBatch;

    /// @notice Mapping to track return requests for batches
    mapping(bytes32 => ReturnRequest) public returnRequests;
    
    ///@notice Mapping to track owners to their batched
    mapping(address => bytes32[]) public ownerToBatches;
    
    /// @notice Array to store pending return requests
    ReturnRequest[] public pendingRequests;
    ///@notice All BatchUIDs
    bytes32[] public allBatchIds;
    /// @notice Counter for the number of batches created
    uint256 public batchCount;

    /// @notice Chainlink price feed for USD to ETH conversion
    AggregatorV3Interface public dataFeed;
    /// @notice Escrow contract to handle payments securely
    Escrow public escrowContract;
    HandlingAddresses public handlingAddresses;
    address public owner;

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
        // string drugName;
        // uint256 productQuantity;
        // uint256 drugQuantity; //Quantity of the drug in the batch
        address manufacturer;
        address distributor;
        address retailer;
        uint256 expiryDate;
        // string status; //e.g. "Manufactured(Manufacturer has it)", "Distributed(Distributer has it)", "Delivered to Retail"
        uint256 timestamp; //Timestamp of the last update
        uint256 price; //Price of the drug in the batch
        uint256 productPrice;
        BatchStatus statusEnum;
        // uint256 mrp; //Maximum Retail Price
        address ipfsHash; //IPFS hash to store additional details off-chain
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
    /// @param timestamp The timestamp when the batch was created
    event BatchCreated(bytes32 indexed batchId, uint256 timestamp);

    /// @notice Event emitted when a distributor purchases a batch
    /// @param batchId The unique identifier for the batch
    /// @param distributor The address of the distributor who purchased the batch
    /// @param statusEnum The status of the batch
    /// @param price The price of the drug in the batch
    /// @param timestamp The timestamp when the batch was created
    event DistributerPurchased(
        bytes32 indexed batchId,
        address distributor,
        BatchStatus statusEnum,
        uint256 price,
        uint256 timestamp
    );

    /// @notice Event emitted when a retailer purchases a batch
    event RetailerPurchased(
        bytes32 indexed batchId,
        address retailer,
        BatchStatus statusEnum,
        uint256 price,
        uint256 timestamp
    );

    /// @notice Event emitted when a batch is eligible for reselling
    /// @param reason The reason for reselling the batch
    event EligibleForResell(
        bytes32 indexed batchId,
        BatchStatus statusEnum,
        address indexed distributor,
        uint256 price,
        uint256 timestamp,
        string reason
    );

    /// @notice Event emitted when a batch is resold
    event ResellingDone(
        bytes32 indexed batchId,
        BatchStatus statusEnum,
        address indexed distributor,
        uint256 price,
        uint256 timestamp
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
        bool approved,
        bool refunded,
        string reason
    );

    /// @notice Event emitted when a return request is approved
    event RequestApproved(
        bytes32 indexed batchId,
        address indexed requester,
        uint256 indexed timestamp,
        bool approved,
        string reason
    );

    /// @notice Event emitted when a refund is processed
    event Refunded(
        bytes32 indexed batchId,
        address indexed to,
        uint256 indexed timestamp,
        bool refunded,
        string reason
    );

    //errors
    error AddressInvalid(address account);
    error InvalidAmount(uint256 _usdAmount);

    /// @notice Constructor to set the deployer as the DEFAULT_ADMIN_ROLE and to set priceFeed
    constructor(
        address _priceFeedAddress,
        address _escrowAddress,
        address _handlingAddresses
    ) HandlingAddresses() {
        owner = msg.sender;
        escrowContract = Escrow(_escrowAddress);
        dataFeed = AggregatorV3Interface(_priceFeedAddress);
        handlingAddresses = HandlingAddresses(_handlingAddresses);
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
    ) public view returns (uint256) {
        uint256 price = getDataFeedLatestAnswer();
        if (price <= 0) {
            revert("Invalid price feed data");
        }
        if (_usdAmount <= 0) {
            revert InvalidAmount(_usdAmount);
        }

        uint256 amountEth = (_usdAmount * 1e26) / price;
        return amountEth;
    }

    /// @notice function to withdraw stcked eth from contract
    function withdraw() public {
        handlingAddresses.hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
        escrowContract.release(msg.sender, address(this).balance);
    }
}
