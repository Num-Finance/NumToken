pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import "src/NumToken.sol";

/**
 * Script to read information from a deployed NumToken contract
 * 
 * This script helps you gather all necessary information for upgrades:
 * - Token metadata (name, symbol, supply)
 * - Proxy and Beacon addresses
 * - Forwarder address
 * - Current state (paused, roles, etc.)
 */
contract GetTokenInfo is Script {
    function run() external {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        string memory rpcUrl = vm.envString("RPC_URL");
        
        console.log("=== READING TOKEN INFORMATION ===");
        console.log("Token Address:", tokenAddress);
        console.log("RPC URL:", rpcUrl);
        console.log("");
        
        // Create interface to read from token
        NumToken token = NumToken(tokenAddress);
        
        // Basic Token Info
        console.log("=== TOKEN METADATA ===");
        try token.name() returns (string memory name) {
            console.log("Name:", name);
        } catch {}
        
        try token.symbol() returns (string memory symbol) {
            console.log("Symbol:", symbol);
        } catch {}
        
        try token.decimals() returns (uint8 decimals) {
            console.log("Decimals:", decimals);
        } catch {}
        
        try token.totalSupply() returns (uint256 supply) {
            console.log("Total Supply:", supply);
        } catch {}
        
        // ERC2771 Info
        console.log("\n=== ERC2771 INFO ===");
        try token.trustedForwarder() returns (address forwarder) {
            console.log("Trusted Forwarder:", forwarder);
        } catch {
            console.log("Could not read forwarder (might not be ERC2771)");
        }
        
        // Circuit Breaker
        console.log("\n=== CIRCUIT BREAKER ===");
        try token.paused() returns (bool isPaused) {
            console.log("Is Paused:", isPaused);
        } catch {}
        
        // Proxy Info
        console.log("\n=== PROXY INFO ===");
        
        // Try to get implementation address
        try this.getImplementation(tokenAddress, rpcUrl) returns (address impl) {
            console.log("Implementation Address:", impl);
        } catch {
            console.log("Could not determine implementation address");
        }
        
        // Try to get Beacon address from BeaconProxy
        try this.getBeacon(tokenAddress, rpcUrl) returns (address beacon) {
            console.log("Beacon Address:", beacon);
            
            // If we have the beacon, try to get its owner
            try this.getBeaconOwner(beacon, rpcUrl) returns (address owner) {
                console.log("Beacon Owner:", owner);
            } catch {}
        } catch {
            console.log("Could not determine beacon address (might not be BeaconProxy)");
        }
        
        // Try to get admin
        try this.getAdmin(tokenAddress, rpcUrl) returns (address admin) {
            console.log("Proxy Admin:", admin);
        } catch {}
        
        // Roles (if we can determine some addresses to check)
        console.log("\n=== ROLES ===");
        console.log("To check specific addresses for roles, use:");
        console.log("cast call", vm.toString(tokenAddress), "hasRole(bytes32,address)(bool)", "ROLE_HASH", "ADDRESS", "--rpc-url", rpcUrl);
        
        console.log("\n=== USEFUL COMMANDS ===");
        console.log("Get forwarder:");
        console.log("cast call", vm.toString(tokenAddress), "trustedForwarder()(address)", "--rpc-url", rpcUrl);
        console.log("\nGet beacon:");
        console.log("cast call", vm.toString(tokenAddress), "beacon()(address)", "--rpc-url", rpcUrl);
        console.log("\nGet implementation:");
        console.log("cast implementation", vm.toString(tokenAddress), "--rpc-url", rpcUrl);
        console.log("\nGet admin:");
        console.log("cast admin", vm.toString(tokenAddress), "--rpc-url", rpcUrl);
        console.log("\nCheck balance:");
        console.log("cast call", vm.toString(tokenAddress), "balanceOf(address)(uint256)", "ADDRESS", "--rpc-url", rpcUrl);
    }
    
    // Helper function to get implementation
    function getImplementation(address proxy, string memory rpcUrl) external view returns (address) {
        // EIP-1967 implementation slot
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 value = vm.load(proxy, slot);
        return address(uint160(uint256(value)));
    }
    
    // Helper function to get beacon
    function getBeacon(address proxy, string memory rpcUrl) external view returns (address) {
        // EIP-1967 beacon slot
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
        bytes32 value = vm.load(proxy, slot);
        return address(uint160(uint256(value)));
    }
    
    // Helper function to get beacon owner
    function getBeaconOwner(address beacon, string memory rpcUrl) external view returns (address) {
        UpgradeableBeacon beaconContract = UpgradeableBeacon(beacon);
        return beaconContract.owner();
    }
    
    // Helper function to get admin
    function getAdmin(address proxy, string memory rpcUrl) external view returns (address) {
        // EIP-1967 admin slot
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        bytes32 value = vm.load(proxy, slot);
        return address(uint160(uint256(value)));
    }
}

