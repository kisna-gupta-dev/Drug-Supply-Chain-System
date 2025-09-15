//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./DrugSupplyChain.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract upKeep is DrugSupplyChain, AutomationCompatibleInterface {
    constructor(
        address priceFeedAddress,
        address escrowAddress,
        address handlingAddresses
    ) DrugSupplyChain(priceFeedAddress, escrowAddress, handlingAddresses) {}

    /// @notice ChainLink automation function (This is used to check if any request is pending for approval for more than 3 days)
    /// @notice CheckUpKeeps checks the condition (here for 3 days)
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool, bytes memory) {
        bytes32 batchId = _findPendingRequest();
        if (batchId != 0) {
            return (true, abi.encode(batchId));
        }
        return (false, "");
    }

    function _findPendingRequest() internal view returns (bytes32) {
        for (uint256 i = 0; i < pendingRequests.length; i++) {
            ReturnRequest storage request = pendingRequests[i];
            if (_isRequestStale(request)) {
                return request.batchId;
            }
        }
        return 0;
    }

    function _isRequestStale(
        ReturnRequest storage request
    ) internal view returns (bool) {
        return (block.timestamp - request.timestamp > 3 days &&
            !request.approved &&
            !request.refunded);
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
}
