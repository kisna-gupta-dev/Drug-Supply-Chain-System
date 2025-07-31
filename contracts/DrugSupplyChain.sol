//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract DrugSupplyChain is AccessControl {
    //The contract is for tracking Supply Chain system of Drugs
    //To ensure the integrity and authenticity of drugs in the supply chain

    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    //mappings
    mapping(address => uint256) public batchCounter; //Counter for batches created by each manufacturer
    mapping(bytes32 => Batch) public batchIdToBatch; //Mapping of batchId to Batch struct for quick access
    mapping(address => bool) public isFrozen; //Mapping to check if an address is frozen
    mapping(bytes32 => ReturnRequest) public returnRequests; // Batch Return Request tracking
    uint256 public batchCount; //Counter for the number of batches created

    AggregatorV3Interface internal dataFeed;

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
        uint256 MRP; //Maximum Retail Price
    }
    struct ReturnRequest {
        address requester;
        string reason;
        bool approved;
        uint256 timestamp;
        bool refunded;
    }

    //Events
    event BatchCreated(
        bytes32 indexed batchId,
        string drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address indexed manufacturer,
        uint256 expiryDate,
        uint256 price,
        string status,
        uint256 timestamp,
        uint256 MRP
    );
    event DistributerPurchased(
        bytes32 indexed batchId,
        string drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address indexed manufacturer,
        address indexed distributor,
        uint256 expiryDate,
        uint256 price,
        string status,
        uint256 timestamp,
        uint256 MRP
    );

    event RetailerPurchased(
        bytes32 indexed batchId,
        string drugName,
        uint256 productQuantity,
        address indexed manufacturer,
        address indexed distributor,
        address retailer,
        uint256 expiryDate,
        uint256 productPrice,
        string status,
        uint256 timestamp,
        uint256 MRP
    );

    event EligibleForResell(
        bytes32 indexed batchId,
        string drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address indexed manufacturer,
        address indexed distributor,
        uint256 expiryDate,
        uint256 price,
        string status,
        uint256 timestamp,
        uint256 MRP,
        string reason
    );

    event ResellingDone(
        bytes32 indexed batchId,
        string drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address indexed manufacturer,
        address indexed distributor,
        uint256 expiryDate,
        uint256 price,
        string status,
        uint256 timestamp,
        uint256 MRP
    );

    event ReturnRequested(
        address indexed requester,
        string reason,
        bool approved,
        uint256 timestamp,
        bool refunded
    );

    event RequestApproved(
        address indexed requester,
        string reason,
        bool approved,
        uint256 timestamp,
        bool refunded
    );

    event AddressFrozen(address account);

    event AddressUnfrozen(address account);

    //Modifiers
    modifier mustBeNew(address newMember) {
        require(
            hasRole(RETAILER_ROLE, newMember) == false,
            "You are already a Retailer, Please use different address"
        );
        require(
            hasRole(MANUFACTURER_ROLE, newMember) == false,
            "You are already a Manufacturer, Please use different address"
        );
        require(
            hasRole(DISTRIBUTOR_ROLE, newMember) == false,
            "You are already a Distributor, Please use different address"
        );
        require(newMember != address(0), "Address must not be zero");
        _;
    }

    modifier notFrozen() {
        require(!isFrozen[msg.sender], "Your address is frozen");
        _;
    }

    //Constructor to set the deployer as the DEFAULT_ADMIN_ROLE
    constructor() {
        dataFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getDataFeedLatestAnswer() internal view returns (uint256) {
        (
            ,
            /* uint80 roundId */ int256 answer /*uint256 startedAt*/ /*uint256 updatedAt*/ /*uint80 answeredInRound*/,
            ,
            ,

        ) = dataFeed.latestRoundData();
        return uint256(answer);
    }

    //IMPORTANT -> THE _usdAMount PASSED MUST BE MULTIPLIESD BY 1e18
    //A very important function to be called for calculating Ethereum from USD entered
    //The function will be first called before any payment is initiated
    //As the inputs are in USD and the transactions are done in eth so we need to convert that USD in Eth
    //First we will convergt USD in ETh then we call any other function
    function calculateEthfromUSD(
        uint256 _usdAmount
    ) internal returns (uint256) {
        uint256 price = getDataFeedLatestAnswer();
        require(price > 0, "Invalid Price Feed");
        require(_usdAmount > 0, "Sent Amount is less");

        uint256 amountEth = (_usdAmount * 1e8) / price;
        return amountEth;
    }

    //Granting Roles to the address according to their working in the supply chain
    //Manufacturer, Distributor, Retailer
    //Only the address with DEFAULT_ADMIN_ROLE can add Manufacturer roles
    function addManufacturer(
        address manufacturer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) mustBeNew(manufacturer) {
        //IMPORTANT: The manufacturer's Identity must be verified offchain as we should not Store Crucial data directly to blockchain,
        // So we use backend APIs to first verify the identity of the manufacturer and then call this fucntion to add the manufacturer
        // This way we get the manufacturer which is verified and authenticated and also to store crucial data we use
        // IPFS or any other decentralized storage system for storage of data
        _grantRole(MANUFACTURER_ROLE, manufacturer);
    }

    function addDistributor(
        address distributor
    ) public onlyRole(DEFAULT_ADMIN_ROLE) mustBeNew(distributor) {
        //IMPORTANT: The distributor's Identity must be verified offchain as we should not Store Crucial data directly to blockchain,
        // So we use backend APIs to first verify the identity of the distributor and then call this

        _grantRole(DISTRIBUTOR_ROLE, distributor);
    }

    function addRetailer(
        address retailer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) mustBeNew(retailer) {
        //IMPORTANT: The retailer's Identity must be verified offchain as we should not Store Crucial data directly to blockchain,
        // So we use backend APIs to first verify the identity of the retailer and then call this
        _grantRole(RETAILER_ROLE, retailer);
    }

    //Batch creation function by Manufacturer
    //Only the address with MANUFACTURER_ROLE can create a batch
    function createBatch(
        string memory drugName,
        uint256 productQuantity,
        uint256 drugQuantity,
        address manufacturer,
        uint256 expiryDate,
        uint256 price,
        uint256 MRP
    ) public onlyRole(MANUFACTURER_ROLE) notFrozen {
        Batch memory newBatch;

        require(
            productQuantity > 0,
            "productQuantity must be greater than zero"
        );
        require(drugQuantity > 0, "drugQuantity must be greater than zero");
        require(
            expiryDate > block.timestamp,
            "Expiry date must be in the future"
        );
        require(bytes(drugName).length > 0, "Drug name must not be empty");
        require(price > 0, "Price must be greater than zero");

        batchCount++;
        newBatch.timestamp = block.timestamp;
        newBatch.status = "Manufactured and ready for distribution";
        newBatch.drugName = drugName;
        newBatch.productQuantity = productQuantity;
        newBatch.manufacturer = manufacturer;
        newBatch.expiryDate = expiryDate;
        newBatch.price = price;
        newBatch.drugQuantity = drugQuantity;
        newBatch.MRP = MRP; //Setting the Maximum Retail Price for the batch

        //Making uniqure batchID for every batch
        //Using keccak256 hash of drugName, manufacturer address, timestamp and batch count
        newBatch.batchId = keccak256(
            abi.encodePacked(
                newBatch.drugName,
                newBatch.manufacturer,
                newBatch.timestamp,
                batchCounter[msg.sender]++ // Using batchCount to ensure uniqueness
            )
        );

        //Storing the batch in the mapping
        batchIdToBatch[newBatch.batchId] = newBatch;
        //Generating QR code for the batch
        //This can be done offchain and stored in IPFS or any other decentralized storage system
        //The QR code can contain the batchId, drugName, productQuantity, manufacturer address,
        //expiryDate, price and status of the batch
        //This QR code can be scanned by the distributor
        //This event is for frontend to know about the batch creation and details wiht this we can generate a QR code for Information
        emit BatchCreated(
            newBatch.batchId,
            newBatch.drugName,
            newBatch.productQuantity,
            newBatch.drugQuantity,
            newBatch.manufacturer,
            newBatch.expiryDate,
            newBatch.price,
            newBatch.status,
            newBatch.timestamp,
            newBatch.MRP
        );
        //Now the batch is created and ready to be listed for distributers to buy
    }

    function buyBatchDistributor(
        bytes32 _batchId,
        uint256 _singleUnitPrice
    ) public payable onlyRole(DISTRIBUTOR_ROLE) notFrozen {
        require(
            (batchIdToBatch[_batchId].drugQuantity * _singleUnitPrice) <
                batchIdToBatch[_batchId].MRP,
            "Single Unit price is to high to be sold for retailer"
        );

        require(
            batchIdToBatch[_batchId].distributor == address(0),
            "Already purchased by another distributor"
        );

        require(
            batchIdToBatch[_batchId].batchId != bytes32(0),
            "Batch does not exist"
        );
        require(
            keccak256(bytes(batchIdToBatch[_batchId].status)) ==
                keccak256(bytes("Manufactured and ready for distribution")),
            "Batch is not available for purchase by Manufacturer"
        );

        require(
            batchIdToBatch[_batchId].expiryDate > block.timestamp,
            "Batch has expired"
        );

        require(msg.value >= batchIdToBatch[_batchId].price, "Less Price Sent");
        excessPayment(_batchId);

        // This is the price at which the distributor will sell the product to the retailer
        // Product price = drugQuantity * Price of a Single Unit of the drug
        batchIdToBatch[_batchId].productPrice =
            batchIdToBatch[_batchId].drugQuantity *
            _singleUnitPrice;
        //Updating the batch details
        batchIdToBatch[_batchId].timestamp = block.timestamp;
        batchIdToBatch[_batchId].distributor = msg.sender;
        batchIdToBatch[_batchId]
            .status = "Distributor is the Owner of the batch and is ready to sell to Retailer";

        emit DistributerPurchased(
            _batchId,
            batchIdToBatch[_batchId].drugName,
            batchIdToBatch[_batchId].productQuantity,
            batchIdToBatch[_batchId].drugQuantity,
            batchIdToBatch[_batchId].manufacturer,
            batchIdToBatch[_batchId].distributor,
            batchIdToBatch[_batchId].expiryDate,
            batchIdToBatch[_batchId].price,
            batchIdToBatch[_batchId].status,
            batchIdToBatch[_batchId].timestamp,
            batchIdToBatch[_batchId].MRP
        );
        // We need to update the information on QR code as well as the owner is now the distributor
    }

    function buyBatchRetailer(
        bytes32 _batchId
    ) public payable onlyRole(RETAILER_ROLE) notFrozen {
        require(
            batchIdToBatch[_batchId].retailer == address(0),
            "Batch is already purchased by another Retailer"
        );
        require(
            batchIdToBatch[_batchId].batchId != bytes32(0),
            "Batch does not exist"
        );
        require(
            batchIdToBatch[_batchId].expiryDate > block.timestamp,
            "Batch has expired"
        );
        require(
            keccak256(bytes(batchIdToBatch[_batchId].status)) ==
                keccak256(
                    bytes(
                        "Distributor is the Owner of the batch and is ready to sell to Retailer"
                    )
                ),
            "Batch is not available for purchase by Distributor"
        );
        require(
            batchIdToBatch[_batchId].productPrice > 0,
            "Product Price is not set"
        );
        require(
            msg.value >= batchIdToBatch[_batchId].productPrice,
            "Less Price Sent"
        );

        excessPayment(_batchId);

        //Updations to be done for retailer
        batchIdToBatch[_batchId].timestamp = block.timestamp;
        batchIdToBatch[_batchId].retailer = msg.sender;
        batchIdToBatch[_batchId].status = "Retailer is the Owner of the batch";
        //Updation in QR code to be done as well
        //The QR code should now contain the retailer's address as well

        // Emit the event for Retailer purchase
        emit RetailerPurchased(
            _batchId,
            batchIdToBatch[_batchId].drugName,
            batchIdToBatch[_batchId].productQuantity,
            batchIdToBatch[_batchId].manufacturer,
            batchIdToBatch[_batchId].distributor,
            batchIdToBatch[_batchId].retailer,
            batchIdToBatch[_batchId].expiryDate,
            batchIdToBatch[_batchId].productPrice,
            batchIdToBatch[_batchId].status,
            batchIdToBatch[_batchId].timestamp,
            batchIdToBatch[_batchId].MRP
        );
    }

    function approveRequest(bytes32 _batchId) public notFrozen {
        require(!returnRequests[_batchId].approved, "Already approved");
        require(!returnRequests[_batchId].refunded, "Already refunded");

        address requester = returnRequests[_batchId].requester;
        require(requester != address(0), "No return request found");

        // Logic branch for roles
        if (
            requester == batchIdToBatch[_batchId].retailer &&
            hasRole(DISTRIBUTOR_ROLE, msg.sender)
        ) {
            // Retailer returning to Distributor
            payable(requester).transfer(batchIdToBatch[_batchId].productPrice);
            batchIdToBatch[_batchId].retailer = address(0);
            batchIdToBatch[_batchId].status = "Returned to Distributor";
        } else if (
            requester == batchIdToBatch[_batchId].distributor &&
            hasRole(MANUFACTURER_ROLE, msg.sender)
        ) {
            // Distributor returning to Manufacturer
            payable(requester).transfer(batchIdToBatch[_batchId].price);
            batchIdToBatch[_batchId].distributor = address(0);
            batchIdToBatch[_batchId].status = "Returned to Manufacturer";
        } else {
            revert("Unauthorized caller for approving this return");
        }

        returnRequests[_batchId].approved = true;
        returnRequests[_batchId].refunded = true;

        emit RequestApproved(
            requester,
            returnRequests[_batchId].reason,
            true,
            block.timestamp,
            true
        );
    }

    function requestReturn(
        bytes32 _batchId,
        string memory reason
    ) public notFrozen {
        require(bytes(reason).length > 0, "Reason must not be empty");
        require(
            ((batchIdToBatch[_batchId].retailer == msg.sender) ||
                (batchIdToBatch[_batchId].distributor == msg.sender)),
            "You are not the owner of this batch"
        );

        returnRequests[_batchId] = ReturnRequest({
            requester: msg.sender,
            reason: reason,
            approved: false,
            timestamp: block.timestamp,
            refunded: false
        });

        if (msg.sender == batchIdToBatch[_batchId].retailer) {
            batchIdToBatch[_batchId].status = "Return requested by retailer";
        } else {
            batchIdToBatch[_batchId].status = "Return requested by distributor";
        }

        emit ReturnRequested(msg.sender, reason, false, block.timestamp, false);
    }

    function rejectRequest(bytes32 _batchId) public {
        address requester = returnRequests[_batchId].requester;
        require(requester != address(0), "No return request");

        if (
            requester == batchIdToBatch[_batchId].retailer &&
            hasRole(DISTRIBUTOR_ROLE, msg.sender)
        ) {
            batchIdToBatch[_batchId]
                .status = "Retailer is the Owner of the batch";
        } else if (
            requester == batchIdToBatch[_batchId].distributor &&
            hasRole(MANUFACTURER_ROLE, msg.sender)
        ) {
            batchIdToBatch[_batchId]
                .status = "Distributor is the Owner of the batch and is ready to sell to Retailer";
        } else {
            revert("Unauthorized to reject this request");
        }

        delete returnRequests[_batchId];
    }

    function excessPayment(bytes32 _batchId) public payable {
        address payable toPay;
        uint256 excessAmount;
        if (
            batchIdToBatch[_batchId].retailer == msg.sender &&
            msg.value > batchIdToBatch[_batchId].productPrice
        ) {
            excessAmount = msg.value - batchIdToBatch[_batchId].productPrice;
            toPay = payable(batchIdToBatch[_batchId].distributor);
        } else {
            excessAmount = msg.value - batchIdToBatch[_batchId].price;
            toPay = payable(batchIdToBatch[_batchId].manufacturer);
        }
        payable(msg.sender).transfer(excessAmount);
        payable(toPay).transfer(msg.value - excessAmount);
    }

    function frozeAddress(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "Cannot freeze the zero address");
        isFrozen[account] = true;
        _revokeRole(MANUFACTURER_ROLE, account);
        _revokeRole(DISTRIBUTOR_ROLE, account);
        _revokeRole(RETAILER_ROLE, account);
        emit AddressFrozen(account);
    }

    function unfreezeAddress(
        address account
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(account != address(0), "Cannot unfreeze the zero address");
        isFrozen[account] = false;
        // Re-assign roles if needed, or just leave it as is
        // _grantRole(MANUFACTURER_ROLE, account);
        // _grantRole(DISTRIBUTOR_ROLE, account);
        // _grantRole(RETAILER_ROLE, account);
        emit AddressUnfrozen(account);
    }

    function eligibleToResell(
        bytes32 _batchId,
        string memory reason,
        uint256 newPrice
    ) public onlyRole(DISTRIBUTOR_ROLE) notFrozen {
        require(
            batchIdToBatch[_batchId].distributor == msg.sender,
            "You are not the owner of this batch"
        );
        require(
            batchIdToBatch[_batchId].retailer == address(0),
            "Batch is already purchased by a retailer"
        );
        require(
            keccak256(bytes(batchIdToBatch[_batchId].status)) ==
                keccak256(
                    bytes(
                        "Distributor is the Owner of the batch and is ready to sell to Retailer"
                    )
                ),
            "Batch is not available for reselling"
        );
        require(
            newPrice < batchIdToBatch[_batchId].price,
            "Reselling price must be less than previous price"
        );
        batchIdToBatch[_batchId].price = newPrice;
        // Update the status to indicate that the distributor wants to resell the batch
        batchIdToBatch[_batchId]
            .status = "Distributor wants to resell the batch to another distributor";

        emit EligibleForResell(
            _batchId,
            batchIdToBatch[_batchId].drugName,
            batchIdToBatch[_batchId].productQuantity,
            batchIdToBatch[_batchId].drugQuantity,
            batchIdToBatch[_batchId].manufacturer,
            batchIdToBatch[_batchId].distributor,
            batchIdToBatch[_batchId].expiryDate,
            batchIdToBatch[_batchId].price,
            batchIdToBatch[_batchId].status,
            batchIdToBatch[_batchId].timestamp,
            batchIdToBatch[_batchId].MRP,
            reason
        );
    }

    //Function to pay for reselling to another distributor
    //To be called by the distributor who is rebuying the batch
    //Here the distributor is the actual owner trying to resell the batch and fucntion is called by newDistributor
    // to buy the batch from the current distributor
    function buyResellBatch(
        bytes32 _batchId,
        address distributor
    ) public payable onlyRole(DISTRIBUTOR_ROLE) notFrozen {
        require(
            batchIdToBatch[_batchId].distributor == distributor,
            "This distributor is not the owner of this batch"
        );
        require(
            batchIdToBatch[_batchId].retailer == address(0),
            "Batch is already purchased by a retailer"
        );
        require(
            keccak256(bytes(batchIdToBatch[_batchId].status)) ==
                keccak256(
                    bytes(
                        "Distributor wants to resell the batch to another distributor"
                    )
                ),
            "Distributor is not ready to resell the batch"
        );
        // Transfer the payment to the manufacturer
        payable(batchIdToBatch[_batchId].distributor).transfer(msg.value);
        batchIdToBatch[_batchId].timestamp = block.timestamp;
        batchIdToBatch[_batchId]
            .status = "Distributor is the Owner of the batch and is ready to sell to Retailer";
        batchIdToBatch[_batchId].distributor = msg.sender; // Update the distributor to the new distributor
        // Emit an event for the resell payment
        emit ResellingDone(
            _batchId,
            batchIdToBatch[_batchId].drugName,
            batchIdToBatch[_batchId].productQuantity,
            batchIdToBatch[_batchId].drugQuantity,
            batchIdToBatch[_batchId].manufacturer,
            batchIdToBatch[_batchId].distributor,
            batchIdToBatch[_batchId].expiryDate,
            batchIdToBatch[_batchId].price,
            batchIdToBatch[_batchId].status,
            batchIdToBatch[_batchId].timestamp,
            batchIdToBatch[_batchId].MRP
        );
    }

    //function to withdraw stcked eth from contract
    function withdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    //Revoking roles in case of any dispute or any issue
    //Only the address with DEFAULT_ADMIN_ROLE can remove Manufacturer roles
    function removeManufacturer(
        address manufacturer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MANUFACTURER_ROLE, manufacturer);
    }

    function removeDistributor(
        address distributor
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DISTRIBUTOR_ROLE, distributor);
    }

    function removeRetailer(
        address retailer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(RETAILER_ROLE, retailer);
    }
}
