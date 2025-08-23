//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DrugSupplyChain.sol";

contract HandlingRequests is DrugSupplyChain {
    function approveRequest(bytes32 _batchId) public notFrozen {
        if (returnRequests[_batchId].requester == address(0)) {
            revert("No return request found");
        }
        if (returnRequests[_batchId].approved) {
            revert("Request already approved");
        }
        if (returnRequests[_batchId].refunded) {
            revert("Request already refunded");
        }
        if (returnRequests[_batchId].timestamp + 7 days < block.timestamp) {
            revert("Request has expired");
        }

        address requester = returnRequests[_batchId].requester;

        // Logic branch for roles
        if (
            requester == batchIdToBatch[_batchId].retailer &&
            hasRole(DISTRIBUTOR_ROLE, msg.sender)
        ) {
            // Retailer returning to Distributor
            // payable(requester).transfer(batchIdToBatch[_batchId].productPrice);
            escrowContract.release(
                batchIdToBatch[_batchId].distributor,
                batchIdToBatch[_batchId].productPrice
            );
            batchIdToBatch[_batchId].retailer = address(0);
            batchIdToBatch[_batchId].status = "Returned to Distributor";
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .ReturnedToDistributor;
        } else if (
            requester == batchIdToBatch[_batchId].distributor &&
            hasRole(MANUFACTURER_ROLE, msg.sender)
        ) {
            // Distributor returning to Manufacturer
            // payable(requester).transfer(batchIdToBatch[_batchId].price);
            escrowContract.release(
                batchIdToBatch[_batchId].manufacturer,
                batchIdToBatch[_batchId].price
            );
            batchIdToBatch[_batchId].distributor = address(0);
            batchIdToBatch[_batchId].status = "Returned to Manufacturer";
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .ReturnedToManufacturer;
        } else {
            revert("Unauthorized caller for approving this return");
        }

        returnRequests[_batchId].approved = true;
        returnRequests[_batchId].refunded = true;

        removePendingRequest(_batchId);
        emit RequestApproved(
            _batchId,
            requester,
            returnRequests[_batchId].reason,
            true,
            block.timestamp,
            true
        );
    }

    function removePendingRequest(bytes32 _batchId) internal {
        for (uint256 i = 0; i < pendingRequests.length; i++) {
            if (
                pendingRequests[i].batchId == returnRequests[_batchId].batchId
            ) {
                // Swap with the last element
                pendingRequests[i] = pendingRequests[
                    pendingRequests.length - 1
                ];
                // Remove the last element
                pendingRequests.pop();
                break;
            }
        }
    }

    function requestReturn(
        bytes32 _batchId,
        string memory reason
    ) public notFrozen {
        if (bytes(reason).length < 0) {
            revert("Reason must not be empty");
        }
        if (
            returnRequests[_batchId].retailer != address(0) ||
            returnRequests[_batchId].distributor != address(0)
        ) {
            revert("Return request for this batch already exists");
        }
        if (
            msg.sender != batchIdToBatch[_batchId].retailer &&
            msg.sender != batchIdToBatch[_batchId].distributor
        ) {
            revert("You are not the owner of this batch");
        }

        returnRequests[_batchId] = ReturnRequest({
            batchId: _batchId,
            requester: msg.sender,
            reason: reason,
            approved: false,
            timestamp: block.timestamp,
            refunded: false
        });
        pendingRequests.push(returnRequests[_batchId]);
        // Update the batch status based on who is requesting the return
        if (msg.sender == batchIdToBatch[_batchId].retailer) {
            batchIdToBatch[_batchId].status = "Return requested by retailer";
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .ReturnRequestedByRetailer;
        } else {
            batchIdToBatch[_batchId].status = "Return requested by distributor";
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .ReturnRequestedByDistributor;
        }

        emit ReturnRequested(
            _batchId,
            msg.sender,
            reason,
            false,
            block.timestamp,
            false
        );
    }

    function rejectRequest(bytes32 _batchId) public {
        if (returnRequests[_batchId].requester == address(0)) {
            revert("No return request");
        }
        address requester = returnRequests[_batchId].requester;
        if (
            requester == batchIdToBatch[_batchId].retailer &&
            hasRole(DISTRIBUTOR_ROLE, msg.sender)
        ) {
            batchIdToBatch[_batchId]
                .status = "Retailer is the Owner of the batch";
            batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByRetailer;
        } else if (
            requester == batchIdToBatch[_batchId].distributor &&
            hasRole(MANUFACTURER_ROLE, msg.sender)
        ) {
            batchIdToBatch[_batchId]
                .status = "Distributor is the Owner of the batch and is ready to sell to Retailer";
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .OwnedByDistributor;
        } else {
            revert("Unauthorized to reject this request");
        }
        removePendingRequest(_batchId);
        delete returnRequests[_batchId];
    }
}
