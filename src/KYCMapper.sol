pragma solidity ^0.8.22;

import "openzeppelin/access/AccessControl.sol";

contract KYCMapper is AccessControl {
    bytes32 public constant KYC_ADMIN_ROLE = keccak256("KYC_ADMIN_ROLE");
    mapping(address => bool) public isAddressWhitelisted;

    constructor() {
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

contract FakeKYCMapper {
    constructor() {}
    function isAddressWhitelisted(address who) public pure returns (bool) {
        return true;
    }
}
