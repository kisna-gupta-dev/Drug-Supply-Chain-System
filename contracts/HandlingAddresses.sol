//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DrugSupplyChain.sol";

//Granting Roles to the address according to their working in the supply chain
//Manufacturer, Distributor, Retailer
//Only the address with DEFAULT_ADMIN_ROLE can add Manufacturer roles
contract HandlingAddresses is DrugSupplyChain {
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
}
