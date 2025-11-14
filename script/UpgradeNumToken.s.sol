pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import "src/NumToken.sol";
import "src/TwinToken.sol";

/**
 * Script to upgrade NumToken to NumTokenV2
 * 
 * This script:
 * 1. Deploys the new NumTokenV2 implementation
 * 2. Upgrades the Beacon to point to V2
 * 3. Initializes V2 with new name and symbol
 * 
 * IMPORTANT: All storage (balances, roles, etc.) is preserved!
 */
contract UpgradeTwinToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address proxyAddress = vm.envAddress("TOKEN_PROXY_ADDRESS");
        address beaconAddress = vm.envAddress("BEACON_ADDRESS");
        address forwarderAddress = vm.envAddress("FORWARDER_ADDRESS");
        
        string memory newName = vm.envString("NEW_TOKEN_NAME");
        string memory newSymbol = vm.envString("NEW_TOKEN_SYMBOL");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Get current token state
        NumToken oldToken = NumToken(proxyAddress);
        
        console.log("=== PRE-UPGRADE STATE ===");
        console.log("Token Address:", proxyAddress);
        console.log("Current Name:", oldToken.name());
        console.log("Current Symbol:", oldToken.symbol());
        console.log("Total Supply:", oldToken.totalSupply());
        console.log("Trusted Forwarder:", oldToken.isTrustedForwarder(forwarderAddress));
        
        // Verify forwarder matches
        require(
            oldToken.isTrustedForwarder(forwarderAddress),
            "Forwarder address mismatch!"
        );
        
        console.log("Forwarder verified:", forwarderAddress);

        // Deploy new V2 implementation
        console.log("\n=== DEPLOYING V2 ===");
        TwinToken newImpl = new TwinToken(forwarderAddress);
        console.log("TwinToken deployed at:", address(newImpl));
        
        // Upgrade the Beacon
        console.log("\n=== UPGRADING BEACON ===");
        console.log("Beacon Address:", beaconAddress);
        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddress);
        beacon.upgradeTo(address(newImpl));
        console.log("Beacon upgraded successfully!");
        
        // Initialize V2 with new metadata
        console.log("\n=== INITIALIZING V2 ===");
        TwinToken tokenV2 = TwinToken(proxyAddress);
        tokenV2.initializeV2(newName, newSymbol);
        console.log("V2 initialized with new metadata");
        
        // Verify post-upgrade state
        console.log("\n=== POST-UPGRADE STATE ===");
        console.log("New Name:", tokenV2.name());
        console.log("New Symbol:", tokenV2.symbol());
        console.log("Total Supply:", tokenV2.totalSupply());
        console.log("Forwarder verified:", tokenV2.isTrustedForwarder(forwarderAddress));
        
        // Verify balances are preserved (check a few if provided)
        string memory checkAddresses = vm.envOr("CHECK_BALANCES", string(""));
        if (bytes(checkAddresses).length > 0) {
            console.log("\n=== BALANCE VERIFICATION ===");
            address[] memory addresses = vm.envAddress("CHECK_BALANCES", ",");
            for (uint i = 0; i < addresses.length; ++i) {
                uint256 balance = tokenV2.balanceOf(addresses[i]);
                console.log("Balance of", vm.toString(addresses[i]), ":", balance);
            }
        }
        
        vm.stopBroadcast();
        
        console.log("\n Upgrade completed successfully!");
        console.log("Token metadata updated while preserving all storage.");
    }
}

