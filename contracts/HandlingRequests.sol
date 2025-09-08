//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DrugSupplyChain.sol";

contract HandlingRequests is DrugSupplyChain {
    constructor(
        address priceFeedAddress,
        address escrowAddress
    ) DrugSupplyChain(priceFeedAddress, escrowAddress) {}

    function approveRequestChecks(bytes32 _batchId) internal view {
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
    }

    function approveRequestRetailer(
        bytes32 _batchId
    ) public onlyRole(DISTRIBUTOR_ROLE) notFrozen {
        approveRequestChecks(_batchId);
        address requester = returnRequests[_batchId].requester;
        // Logic branch for roles
        if (requester == batchIdToBatch[_batchId].retailer) {
            returnRequests[_batchId].approved = true;
            refundPayment(_batchId, requester);
            batchIdToBatch[_batchId].retailer = address(0);
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .ReturnedToDistributor;
        } else {
            revert("Unauthorized caller for approving this return");
        }
        emit RequestApproved(
            _batchId,
            requester,
            block.timestamp,
            true,
            returnRequests[_batchId].reason
        );
    }

    function approveRequestDistributor(
        bytes32 _batchId
    ) public onlyRole(MANUFACTURER_ROLE) notFrozen {
        approveRequestChecks(_batchId);
        address requester = returnRequests[_batchId].requester;

        if (requester == batchIdToBatch[_batchId].distributor) {
            returnRequests[_batchId].approved = true;
            refundPayment(_batchId, requester);
            batchIdToBatch[_batchId].distributor = address(0);
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .ReturnedToManufacturer;
        } else {
            revert("Unauthorized caller for approving this return");
        }
        emit RequestApproved(
            _batchId,
            requester,
            block.timestamp,
            true,
            returnRequests[_batchId].reason
        );
    }

    function refundPayment(bytes32 _batchId, address to) internal notFrozen {
        returnRequests[_batchId].refunded = true;
        to = batchIdToBatch[_batchId].manufacturer;

        escrowContract.release(to, batchIdToBatch[_batchId].price);
        removePendingRequest(_batchId);
        delete returnRequests[_batchId];
        emit Refunded(
            _batchId,
            to,
            block.timestamp,
            true,
            returnRequests[_batchId].reason
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

    function requestReturnChecks(
        bytes32 _batchId,
        string memory reason
    ) internal view {
        if (bytes(reason).length > 256) {
            revert("Reason too long");
        }
        if (returnRequests[_batchId].requester != address(0)) {
            revert("Return request for this batch already exists");
        }
        if (
            msg.sender != batchIdToBatch[_batchId].retailer &&
            msg.sender != batchIdToBatch[_batchId].distributor
        ) {
            revert("You are not the owner of this batch");
        }
    }

    function requestReturn(
        bytes32 _batchId,
        string memory reason
    ) public notFrozen {
        requestReturnChecks(_batchId, reason);
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
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .ReturnRequestedByRetailer;
        } else {
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .ReturnRequestedByDistributor;
        }

        emit ReturnRequested(
            _batchId,
            block.timestamp,
            msg.sender,
            false,
            false,
            reason
        );
    }

    function rejectRequest(bytes32 _batchId) public {
        approveRequestChecks(_batchId);
        address requester = returnRequests[_batchId].requester;
        if (
            requester == batchIdToBatch[_batchId].retailer &&
            hasRole(DISTRIBUTOR_ROLE, msg.sender)
        ) {
            batchIdToBatch[_batchId].statusEnum = BatchStatus.OwnedByRetailer;
        } else if (
            requester == batchIdToBatch[_batchId].distributor &&
            hasRole(MANUFACTURER_ROLE, msg.sender)
        ) {
            batchIdToBatch[_batchId].statusEnum = BatchStatus
                .OwnedByDistributor;
        } else {
            revert("Unauthorized to reject this request");
        }
        removePendingRequest(_batchId);
        delete returnRequests[_batchId];
    }
}
