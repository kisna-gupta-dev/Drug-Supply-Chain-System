//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import "./DrugSupplyChain.sol";

contract BasicMechanism is DrugSupplyChain {
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

        if(productQuantity < 0){
            revert("productQuantity must be greater than zero");
        }
        if(drugQuantity < 0){
            revert("drugQuantity must be greater than zero");
        } 
        if( expiryDate < block.timestamp){
            revert("Expiry date must be in the future");
        }
        if(bytes(drugName).length <= 0){
            revert("Drug name must not be empty");
        }
            
        if(price < 0) {
            revert("Price must be greater than zero");
        }

        batchCount++;
        newBatch.timestamp = block.timestamp;
        statusEnum = BatchStatus.Manufactured;
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
            newBatch.statusEnum,
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
       
            if((batchIdToBatch[_batchId].drugQuantity * _singleUnitPrice) > batchIdToBatch[_batchId].MRP){
                revert("Single Unit price is to high to be sold for retailer");
            }
            if(_singleUnitPrice <= 0){
                revert("Single Unit Price must be greater than zero");
            }
            if( batchIdToBatch[_batchId].distributor != address(0)){
                revert("Batch is already purchased by another distributor");
            }
            if(batchIdToBatch[_batchId].batchId == bytes32(0)){
                revert("Batch does not exist");
            }
            if(batchIdToBatch[_batchId].statusEnum != BatchStatus.Manufactured){
                revert("Batch is not available for purchase by Distributor");
            }
            if(batchIdToBatch[_batchId].expiryDate <= block.timestamp){
                revert("Batch has expired");
            }
            if(batchIdToBatch[_batchId].price <= 0){
                revert("Price is not set by manufacturer");
            }

        require(msg.value >= batchIdToBatch[_batchId].price, "Less Price Sent");
        //Escrow Contract to handle the payment
        escrowContract
            .buy{value: msg.value}(msg.sender, batchIdToBatch[_batchId].manufacturer);

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
        batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByDistributor;

        emit DistributerPurchased(
            _batchId,
            batchIdToBatch[_batchId].statusEnum,
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
        if( batchIdToBatch[_batchId].retailer != address(0)){
                revert("Batch is already purchased by another retailer");
            }
            if(batchIdToBatch[_batchId].batchId == bytes32(0)){
                revert("Batch does not exist");
            }
            if(batchIdToBatch[_batchId].statusEnum != BatchStatus.OwnedByDistributor){
                revert("Batch is not available for purchase by Retailer");
            }
            if(batchIdToBatch[_batchId].expiryDate <= block.timestamp){
                revert("Batch has expired");
            }
            if(msg.value <= batchIdToBatch[_batchId].productPrice){
                revert("Payment must be greater than productPrice");
            }
            if(batchIdToBatch[_batchId].productPrice <= 0){
                revert("Product Price is not set");
            }

        //Escrow Contract to handle the payment
        escrowContract
            .buy{value: msg.value}(msg.sender, batchIdToBatch[_batchId].distributor);

        //Updations to be done for retailer
        batchIdToBatch[_batchId].timestamp = block.timestamp;
        batchIdToBatch[_batchId].retailer = msg.sender;
        batchIdToBatch[_batchId].status = "Retailer is the Owner of the batch";
        batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByRetailer;
        //Updation in QR code to be done as well
        //The QR code should now contain the retailer's address as well

        // Emit the event for Retailer purchase
        emit RetailerPurchased(
            _batchId,
            batchIdToBatch[_batchId].statusEnum,
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

    function batchReceived(
        bytes32 _batchId
    ) internal payable onlyRole(RETAILER_ROLE) onlyRole(DISTRIBUTOR_ROLE) notFrozen {
        if(
            batchIdToBatch[_batchId].retailer == msg.sender &&
            hasRole(RETAILER_ROLE, msg.sender)
        ) {
            // Retailer receiving the batch
            batchIdToBatch[_batchId].status = "Retailer has received the batch";
            batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByRetailer;
            escrowContract.release(
                batchIdToBatch[_batchId].distributor,
                batchIdToBatch[_batchId].productPrice
            );
        } else if (
            batchIdToBatch[_batchId].distributor == msg.sender &&
            hasRole(DISTRIBUTOR_ROLE, msg.sender)
        ) {
            // Distributor receiving the batch
            batchIdToBatch[_batchId].status = "Distributor has received the batch";
            batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByDistributor;
            escrowContract.release(
                batchIdToBatch[_batchId].manufacturer,
                batchIdToBatch[_batchId].price
            );
        } else {
            revert("Unauthorized to mark this batch as received");
        }

        // Logic to mark the batch as received by the retailer
        // This can include updating the status or any other necessary actions
    }
}
