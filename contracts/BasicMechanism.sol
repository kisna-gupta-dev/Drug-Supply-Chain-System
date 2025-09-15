//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DrugSupplyChain.sol";

contract BasicMechanism is DrugSupplyChain {
    constructor(
        address priceFeedAddress,
        address escrowAddress,
        address handlingAddresses
    ) DrugSupplyChain(priceFeedAddress, escrowAddress, handlingAddresses) {}

    function checkDataReceived(
        address manufacturer,
        uint256 expiryDate,
        uint256 price
    ) internal view {
        if (!handlingAddresses.hasRole(MANUFACTURER_ROLE, msg.sender)) {
            revert("Its not Manufacturer");
        }
        if (manufacturer == address(0)) {
            revert("Manufacturer address cannot be zero");
        }

        if (expiryDate < block.timestamp) {
            revert("Expiry date must be in the future");
        }
        if (price <= 0) {
            revert("Price must be greater than zero");
        }
    }

    function updatingParams(
        address manufacturer,
        uint256 expiryDate,
        uint256 price,
        address ipfsHash
    ) internal {
        Batch memory newBatch;
        newBatch.statusEnum = BatchStatus.Manufactured;
        newBatch.timestamp = block.timestamp;
        newBatch.ipfsHash = ipfsHash;
        batchCount++;
        newBatch.manufacturer = manufacturer;
        newBatch.expiryDate = expiryDate;
        newBatch.price = price;

        uint256 idx = batchCounter[msg.sender]++;

        //Making uniqure batchID for every batch
        //Using keccak256 hash of drugName, manufacturer address, timestamp and batch count
        newBatch.batchId = keccak256(
            abi.encodePacked(
                newBatch.manufacturer,
                newBatch.timestamp,
                idx // Using batchCount to ensure uniqueness
            )
        );

        //Storing the batch in the mapping
        batchIdToBatch[newBatch.batchId] = newBatch;
        //This event is for frontend to know about the batch creation and details wiht this we can generate a QR code for Information
        emit BatchCreated(newBatch.batchId, newBatch.timestamp);
        //Now the batch is created and ready to be listed for distributers to buy
    }

    function createBatch(
        address manufacturer,
        uint256 expiryDate,
        uint256 price,
        address ipfsHash
    ) public notFrozen {
        checkDataReceived(manufacturer, expiryDate, price);
        updatingParams(manufacturer, expiryDate, price, ipfsHash);
        //Generating QR code for the batch
        //This can be done offchain and stored in IPFS or any other decentralized storage system
        //The QR code can contain the batchId, drugName, productQuantity, manufacturer address,
        //expiryDate, price and status of the batch
        //This QR code can be scanned by the distributor
    }

    function distributorBuyingChecks(
        bytes32 _batchId,
        uint256 _productPrice
    ) internal view {
        if (!handlingAddresses.hasRole(DISTRIBUTOR_ROLE, msg.sender)) {
            revert("Its not Distributor");
        }
        // Add any common checks for distributor buying here
        if (batchIdToBatch[_batchId].distributor != address(0)) {
            revert("Batch is already purchased by another distributor");
        }
        if (batchIdToBatch[_batchId].batchId == bytes32(0)) {
            revert("Batch does not exist");
        }
        if (batchIdToBatch[_batchId].statusEnum != BatchStatus.Manufactured) {
            revert("Batch is not available for purchase by Distributor");
        }
        if (batchIdToBatch[_batchId].expiryDate <= block.timestamp) {
            revert("Batch has expired");
        }
        if (msg.value < batchIdToBatch[_batchId].price) {
            revert("Insufficient Price Sent");
        }
        if (_productPrice <= 0) {
            revert("Product price must be greater than zero");
        }
    }

    function buyBatchDistributor(
        bytes32 _batchId,
        uint256 _productPrice
    ) public payable notFrozen {
        distributorBuyingChecks(_batchId, _productPrice);

        require(msg.value >= batchIdToBatch[_batchId].price, "Less Price Sent");
        //Escrow Contract to handle the payment
        escrowContract.buy{value: msg.value}(
            msg.sender,
            batchIdToBatch[_batchId].manufacturer
        );

        // This is the price at which the distributor will sell the product to the retailer
        // Product price = drugQuantity * Price of a Single Unit of the drug
        batchIdToBatch[_batchId].productPrice = _productPrice;

        //Updating the batch details
        batchIdToBatch[_batchId].timestamp = block.timestamp;
        batchIdToBatch[_batchId].distributor = msg.sender;

        batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByDistributor;

        emit DistributerPurchased(
            _batchId,
            batchIdToBatch[_batchId].distributor,
            batchIdToBatch[_batchId].statusEnum,
            batchIdToBatch[_batchId].price,
            batchIdToBatch[_batchId].timestamp
        );
        // We need to update the information on QR code as well as the owner is now the distributor
    }

    function retailerBuyingChecks(bytes32 _batchId) internal view {
        if (!handlingAddresses.hasRole(RETAILER_ROLE, msg.sender)) {
            revert("Its not Retailer");
        }
        // Add any common checks for retailer buying here
        if (batchIdToBatch[_batchId].retailer != address(0)) {
            revert("Batch is already purchased by another retailer");
        }
        if (batchIdToBatch[_batchId].batchId == bytes32(0)) {
            revert("Batch does not exist");
        }
        if (
            batchIdToBatch[_batchId].statusEnum !=
            BatchStatus.OwnedByDistributor
        ) {
            revert("Batch is not available for purchase by Retailer");
        }
        if (batchIdToBatch[_batchId].expiryDate <= block.timestamp) {
            revert("Batch has expired");
        }
        if (msg.value < batchIdToBatch[_batchId].productPrice) {
            revert("Payment must be greater than productPrice");
        }
        if (batchIdToBatch[_batchId].productPrice <= 0) {
            revert("Product Price is not set");
        }
    }

    function buyBatchRetailer(bytes32 _batchId) public payable notFrozen {
        retailerBuyingChecks(_batchId);

        //Escrow Contract to handle the payment
        escrowContract.buy{value: msg.value}(
            msg.sender,
            batchIdToBatch[_batchId].distributor
        );

        //Updations to be done for retailer
        batchIdToBatch[_batchId].timestamp = block.timestamp;
        batchIdToBatch[_batchId].retailer = msg.sender;
        batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByRetailer;
        //Updation in QR code to be done as well
        //The QR code should now contain the retailer's address as well

        // Emit the event for Retailer purchase
        emit RetailerPurchased(
            _batchId,
            batchIdToBatch[_batchId].retailer,
            batchIdToBatch[_batchId].statusEnum,
            batchIdToBatch[_batchId].price,
            batchIdToBatch[_batchId].timestamp
        );
    }

    function batchReceivedRetailer(bytes32 _batchId) public payable notFrozen {
        if (!handlingAddresses.hasRole(RETAILER_ROLE, msg.sender)) {
            revert("Its not Retailer");
        }
        if (batchIdToBatch[_batchId].retailer == msg.sender) {
            // Retailer receiving the batch
            batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByRetailer;
            escrowContract.release(
                batchIdToBatch[_batchId].distributor,
                batchIdToBatch[_batchId].productPrice
            );
        } else {
            revert("Unauthorized to mark this batch as received");
        }

        // Logic to mark the batch as received by the retailer
        // This can include updating the status or any other necessary actions
    }

    function batchReceivedDistributor(bytes32 _batchId) public notFrozen {
        if (!handlingAddresses.hasRole(DISTRIBUTOR_ROLE, msg.sender)) {
            revert("Its not Distributor");
        }
        if (batchIdToBatch[_batchId].distributor == msg.sender) {
            // Distributor receiving the batch
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .OwnedByDistributor;
            escrowContract.release(
                batchIdToBatch[_batchId].manufacturer,
                batchIdToBatch[_batchId].price
            );
        } else {
            revert("Unauthorized to mark this batch as received");
        }

        // Logic to mark the batch as received by the distributor
        // This can include updating the status or any other necessary actions
    }

    function getBatchDetails(
        bytes32 _batchId
    ) public view returns (Batch memory) {
        if (batchIdToBatch[_batchId].batchId == bytes32(0)) {
            revert("Batch does not exist");
        }
        return batchIdToBatch[_batchId];
    }

    function getIpfsHash(bytes32 _batchId) public view returns (address) {
        if (batchIdToBatch[_batchId].batchId == bytes32(0)) {
            revert("Batch does not exist");
        }
        return batchIdToBatch[_batchId].ipfsHash;
    }
}
