pragma solidity ^0.8.15;

import "src/NumToken.sol";

/**
 * NumTokenV2 - Upgrade version of NumToken
 * 
 * This contract adds the ability to update the token name and symbol
 * after deployment while preserving all storage (balances, roles, etc.)
 */
contract TwinToken is NumToken {
    /**
     * @notice Constructor that takes the same forwarder as V1
     * @param forwarder_ The ERC2771 forwarder address (must match V1)
     */
    constructor(address forwarder_) NumToken(forwarder_) {}

    /**
     * @notice Updates the token name and symbol
     * @dev Uses reinitializer(2) to allow calling after upgrade from V1
     *      This only updates name/symbol, all other storage remains unchanged
     * @param newName The new token name
     * @param newSymbol The new token symbol
     */
    function initializeV2(
        string memory newName,
        string memory newSymbol
    ) public reinitializer(2) {
        // Reinitialize ERC20 with new name and symbol
        // This only updates _name and _symbol, balances and other storage are untouched
        __ERC20_init(newName, newSymbol);
    }
}

