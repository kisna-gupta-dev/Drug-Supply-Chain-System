//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DrugSupplyChain.sol";

contract ResellMechanism is DrugSupplyChain {
    constructor(
        address priceFeedAddress,
        address escrowAddress
    ) DrugSupplyChain(priceFeedAddress, escrowAddress) {}

    function eligibleToResell(
        bytes32 _batchId,
        string memory reason,
        uint256 newPrice
    ) public onlyRole(DISTRIBUTOR_ROLE) notFrozen {
        if (batchIdToBatch[_batchId].distributor != msg.sender) {
            revert("You are not the owner of this batch");
        }
        if (batchIdToBatch[_batchId].expiryDate <= block.timestamp) {
            revert("Batch has expired");
        }
        if (batchIdToBatch[_batchId].retailer != address(0)) {
            revert("Batch is already purchased by a retailer");
        }
        if (newPrice <= 0 || newPrice < batchIdToBatch[_batchId].price) {
            revert("New price must be greater than zero and previous price");
        }
        if (
            batchIdToBatch[_batchId].statusEnum !=
            BatchStatus.OwnedByDistributor
        ) {
            revert("Batch is not owned by distributor");
        }
        // Update the price of the batch
        batchIdToBatch[_batchId].price = newPrice;
        // Update the status to indicate that the distributor wants to resell the batch
        batchIdToBatch[_batchId].statusEnum = BatchStatus
            .ResellingToDistributor;

        emit EligibleForResell(
            _batchId,
            batchIdToBatch[_batchId].statusEnum,
            batchIdToBatch[_batchId].distributor,
            batchIdToBatch[_batchId].price,
            batchIdToBatch[_batchId].timestamp,
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
        if (batchIdToBatch[_batchId].distributor != distributor) {
            revert("This distributor is not the owner of this batch");
        }
        if (batchIdToBatch[_batchId].expiryDate <= block.timestamp) {
            revert("Batch has expired");
        }
        if (batchIdToBatch[_batchId].retailer != address(0)) {
            revert("Batch is already purchased by a retailer");
        }
        if (msg.value <= 0 || msg.value < batchIdToBatch[_batchId].price) {
            revert("Insifficient Payment");
        }
        if (
            batchIdToBatch[_batchId].statusEnum !=
            BatchStatus.ResellingToDistributor
        ) {
            revert("Batch is not available for resell");
        }

        // Transfer the payment to the distributor
        escrowContract.buy{value: msg.value}(
            msg.sender,
            batchIdToBatch[_batchId].distributor
        );
        batchIdToBatch[_batchId].timestamp = block.timestamp;
        batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByDistributor;
        batchIdToBatch[_batchId].distributor = msg.sender; // Update the distributor to the new distributor
        // Emit an event for the resell payment
        emit ResellingDone(
            _batchId,
            batchIdToBatch[_batchId].statusEnum,
            batchIdToBatch[_batchId].distributor,
            batchIdToBatch[_batchId].price,
            batchIdToBatch[_batchId].timestamp
        );
    }
}
