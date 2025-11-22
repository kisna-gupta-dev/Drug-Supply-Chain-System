//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

//Granting Roles to the address according to their working in the supply chain
//Manufacturer, Distributor, Retailer
//Only the address with DEFAULT_ADMIN_ROLE can add Manufacturer roles
contract HandlingAddresses is AccessControl {
    /// @notice Mapping to check if an address is frozen
    mapping(address => bool) public isFrozen;

    /// @notice Role identifier for manufacturers in the supply chain
    bytes32 public constant MANUFACTURER_ROLE = keccak256("MANUFACTURER_ROLE");
    /// @notice Role identifier for distributors in the supply chain
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    /// @notice Role identifier for retailers in the supply chain
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    /// @notice Event emitted when an address is frozen
    /// @param account The account address needs to be frozen
    event AddressFrozen(address account);
    /// @notice Event emitted when an address is unfrozen
    /// @param account The account address needs to be unfreeze
    event AddressUnfrozen(address account);

    error AddressAlreadyExists(string role, address account);

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
            revert("Address Invalid");
        }
        _;
    }
    modifier notFrozen() {
        if (isFrozen[msg.sender]) {
            revert("Address Invalid");
        }
        _;
    }

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addManufacturer(
        address manufacturer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) mustBeNew(manufacturer) {
        //IMPORTANT: The manufacturer's Identity must be verified offchain as we should not Store Crucial data directly to blockchain,
        // So we use backend APIs to first verify the identity of the manufacturer and then call this fucntion to add the manufacturer
        // This way we get the manufacturer which is verified and authenticated and also to store crucial data we use
        // IPFS or any other decentralized storage system for storage of data
        grantRole(MANUFACTURER_ROLE, manufacturer);
    }

    function addDistributor(
        address distributor
    ) public onlyRole(DEFAULT_ADMIN_ROLE) mustBeNew(distributor) {
        //IMPORTANT: The distributor's Identity must be verified offchain as we should not Store Crucial data directly to blockchain,
        // So we use backend APIs to first verify the identity of the distributor and then call this

        grantRole(DISTRIBUTOR_ROLE, distributor);
    }

    function addRetailer(
        address retailer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) mustBeNew(retailer) {
        //IMPORTANT: The retailer's Identity must be verified offchain as we should not Store Crucial data directly to blockchain,
        // So we use backend APIs to first verify the identity of the retailer and then call this
        grantRole(RETAILER_ROLE, retailer);
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

    /// @notice Rvoking Manufacturer Role, Only DEFAULT_ADMIN_ROLE can remove Manufacturer roles
    /// @param manufacturer Address of manufacturer to revoke role
    function removeManufacturer(
        address manufacturer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MANUFACTURER_ROLE, manufacturer);
    }

    /// @notice Revoking distributor Role, Only DEFAULT_ADMIN_ROLE can remove Manufacturer roles
    /// @param distributor Address of distributor to revoke role
    function removeDistributor(
        address distributor
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(DISTRIBUTOR_ROLE, distributor);
    }

    /// @notice Revoking retailer Role, Only DEFAULT_ADMIN_ROLE can remove Manufacturer roles
    /// @param retailer Address of retailer to revoke role
    function removeRetailer(
        address retailer
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(RETAILER_ROLE, retailer);
    }

    ///@notice Function to check if an address has a role
    function checkRole(
        string memory roleName,
        address account
    ) public view returns (bool) {
        bytes32 role;
        if(keccak256(bytes(roleName)) == keccak256("MANUFACTURER_ROLE")){
            role = MANUFACTURER_ROLE;
        } else if(keccak256(bytes(roleName)) == keccak256("DISTRIBUTOR_ROLE")){
            role = DISTRIBUTOR_ROLE;
        } else if(keccak256(bytes(roleName)) == keccak256("RETAILER_ROLE")){
            role = RETAILER_ROLE;
        } else {
            revert("Invalid role name");
        }
        return hasRole(role, account);
    }
}
