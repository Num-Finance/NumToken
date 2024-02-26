pragma solidity ^0.8.22;

import "openzeppelin/access/AccessControl.sol";
import "forge-std/console.sol";

contract KYCMapper is AccessControl {
    bytes32 public constant KYC_ADMIN_ROLE = keccak256("KYC_ADMIN_ROLE");
    mapping(address => bool) public isAddressWhitelisted;

    constructor() {
        console.log(msg.sender);
        _grantRole(
            DEFAULT_ADMIN_ROLE,
            msg.sender
        );
        _grantRole(
            KYC_ADMIN_ROLE, 
            msg.sender    
        );
        _setRoleAdmin(KYC_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    }

    event WhitelistStatusChanged(address who, bool status);

    function setAddressWhitelisted(address who, bool whitelisted) public onlyRole(KYC_ADMIN_ROLE) {
        isAddressWhitelisted[who] = whitelisted;
        emit WhitelistStatusChanged(who, whitelisted);
    }
}