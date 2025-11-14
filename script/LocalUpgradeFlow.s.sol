// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import "src/NumToken.sol";
import "src/TwinToken.sol";

/**
 * @title LocalUpgradeFlow
 * @notice Script completo para testear el upgrade NumToken -> TwinToken en blockchain local
 *
 * Este script simula el flujo completo:
 * 1. Deploy NumToken V1 (Beacon + Proxy)
 * 2. Setup inicial: mint tokens, grant roles, blacklist addresses
 * 3. Snapshot del estado pre-upgrade
 * 4. Upgrade a TwinToken V2
 * 5. Verificación que todo se preservó
 *
 * Para ejecutar en Anvil:
 * 1. Levantá Anvil: anvil
 * 2. En otra terminal: forge script script/LocalUpgradeFlow.s.sol:LocalUpgradeFlow --rpc-url http://localhost:8545 --broadcast
 */
contract LocalUpgradeFlow is Script {
    // Contratos
    NumToken public tokenV1;
    TwinToken public tokenV2;
    UpgradeableBeacon public beacon;
    BeaconProxy public proxy;

    // Addresses (usando las default de Anvil)
    address public deployer;
    address public user1;
    address public user2;
    address public user3;
    address public minter;
    address public circuitBreaker;
    address public disallower;
    address public forwarder;

    // Roles
    bytes32 public constant MINTER_BURNER_ROLE = keccak256("MINTER_BURNER_ROLE");
    bytes32 public constant CIRCUIT_BREAKER_ROLE = keccak256("CIRCUIT_BREAKER_ROLE");
    bytes32 public constant DISALLOW_ROLE = keccak256("DISALLOW_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // State pre-upgrade para verificación
    uint256 user1BalanceBefore;
    uint256 user2BalanceBefore;
    uint256 user3BalanceBefore;
    uint256 totalSupplyBefore;
    bool user2DisallowedBefore;
    bool user3DisallowedBefore;
    bool isPausedBefore;

    function run() external {
        // Setup addresses (Anvil default accounts)
        deployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;      // Account #0
        user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;         // Account #1
        user2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;         // Account #2
        user3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;         // Account #3
        minter = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;        // Account #4
        circuitBreaker = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc; // Account #5
        disallower = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;    // Account #6
        forwarder = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;     // Account #7

        vm.startBroadcast(deployer);

        // ==========================================
        // PASO 1: DEPLOY NUMTOKEN V1
        // ==========================================
        console.log("===========================================");
        console.log("PASO 1: DEPLOYING NUMTOKEN V1");
        console.log("===========================================\n");

        // Deploy implementation V1
        NumToken tokenImpl = new NumToken(forwarder);
        console.log("[DEPLOYED] NumToken V1 Implementation:", address(tokenImpl));

        // Deploy Beacon
        beacon = new UpgradeableBeacon(address(tokenImpl));
        console.log("[DEPLOYED] UpgradeableBeacon:", address(beacon));
        console.log("  Beacon Owner:", beacon.owner());

        // Deploy Proxy
        bytes memory initData = abi.encodeWithSelector(
            NumToken.initialize.selector,
            "Num Token",
            "NUM",
            18
        );
        proxy = new BeaconProxy(address(beacon), initData);
        console.log("[DEPLOYED] BeaconProxy:", address(proxy));

        // Cast proxy to NumToken
        tokenV1 = NumToken(address(proxy));
        console.log("\n[SUCCESS] NumToken V1 deployed and initialized");
        console.log("  Name:", tokenV1.name());
        console.log("  Symbol:", tokenV1.symbol());
        console.log("  Decimals:", tokenV1.decimals());

        // ==========================================
        // PASO 2: SETUP INICIAL
        // ==========================================
        console.log("\n===========================================");
        console.log("PASO 2: CONFIGURANDO ESTADO INICIAL");
        console.log("===========================================\n");

        // Grant roles
        console.log("[SETUP] Granting roles...");
        tokenV1.grantRole(MINTER_BURNER_ROLE, minter);
        console.log("  MINTER_BURNER_ROLE granted to:", minter);

        tokenV1.grantRole(CIRCUIT_BREAKER_ROLE, circuitBreaker);
        console.log("  CIRCUIT_BREAKER_ROLE granted to:", circuitBreaker);

        tokenV1.grantRole(DISALLOW_ROLE, disallower);
        console.log("  DISALLOW_ROLE granted to:", disallower);

        vm.stopBroadcast();

        // Mint tokens (as minter)
        console.log("\n[SETUP] Minting tokens...");
        vm.startBroadcast(minter);
        tokenV1.mint(user1, 10000e18);
        console.log("  Minted 10,000 NUM to user1:", user1);

        tokenV1.mint(user2, 5000e18);
        console.log("  Minted 5,000 NUM to user2:", user2);

        tokenV1.mint(user3, 2500e18);
        console.log("  Minted 2,500 NUM to user3:", user3);
        vm.stopBroadcast();

        // Blacklist user2 (as disallower)
        console.log("\n[SETUP] Configuring blacklist...");
        vm.startBroadcast(disallower);
        tokenV1.disallow(user2);
        console.log("  user2 blacklisted:", user2);
        vm.stopBroadcast();

        // Pause token (as circuit breaker)
        console.log("\n[SETUP] Pausing token...");
        vm.startBroadcast(circuitBreaker);
        tokenV1.togglePause();
        console.log("  Token paused:", tokenV1.paused());
        vm.stopBroadcast();

        // ==========================================
        // PASO 3: SNAPSHOT PRE-UPGRADE
        // ==========================================
        console.log("\n===========================================");
        console.log("PASO 3: ESTADO PRE-UPGRADE (SNAPSHOT)");
        console.log("===========================================\n");

        user1BalanceBefore = tokenV1.balanceOf(user1);
        user2BalanceBefore = tokenV1.balanceOf(user2);
        user3BalanceBefore = tokenV1.balanceOf(user3);
        totalSupplyBefore = tokenV1.totalSupply();
        user2DisallowedBefore = tokenV1.isDisallowed(user2);
        user3DisallowedBefore = tokenV1.isDisallowed(user3);
        isPausedBefore = tokenV1.paused();

        console.log("[STATE] Token Metadata:");
        console.log("  Name:", tokenV1.name());
        console.log("  Symbol:", tokenV1.symbol());
        console.log("  Total Supply:", totalSupplyBefore);

        console.log("\n[STATE] Balances:");
        console.log("  user1:", user1BalanceBefore);
        console.log("  user2:", user2BalanceBefore);
        console.log("  user3:", user3BalanceBefore);

        console.log("\n[STATE] Roles:");
        console.log("  deployer has DEFAULT_ADMIN_ROLE:", tokenV1.hasRole(DEFAULT_ADMIN_ROLE, deployer));
        console.log("  minter has MINTER_BURNER_ROLE:", tokenV1.hasRole(MINTER_BURNER_ROLE, minter));
        console.log("  circuitBreaker has CIRCUIT_BREAKER_ROLE:", tokenV1.hasRole(CIRCUIT_BREAKER_ROLE, circuitBreaker));
        console.log("  disallower has DISALLOW_ROLE:", tokenV1.hasRole(DISALLOW_ROLE, disallower));

        console.log("\n[STATE] Blacklist:");
        console.log("  user2 isDisallowed:", user2DisallowedBefore);
        console.log("  user3 isDisallowed:", user3DisallowedBefore);

        console.log("\n[STATE] Circuit Breaker:");
        console.log("  isPaused:", isPausedBefore);

        console.log("\n[STATE] ERC2771:");
        console.log("  Trusted Forwarder:", forwarder);
        console.log("  isTrustedForwarder:", tokenV1.isTrustedForwarder(forwarder));

        // ==========================================
        // PASO 4: UPGRADE A TWINTOKEN V2
        // ==========================================
        console.log("\n===========================================");
        console.log("PASO 4: UPGRADING TO TWINTOKEN V2");
        console.log("===========================================\n");

        vm.startBroadcast(deployer);

        // Deploy TwinToken implementation
        TwinToken twinImpl = new TwinToken(forwarder);
        console.log("[DEPLOYED] TwinToken V2 Implementation:", address(twinImpl));

        // Upgrade beacon
        beacon.upgradeTo(address(twinImpl));
        console.log("[UPGRADED] Beacon now points to:", beacon.implementation());

        // Cast proxy to TwinToken
        tokenV2 = TwinToken(address(proxy));

        // Initialize V2 with new name and symbol
        tokenV2.initializeV2("Twin Token", "TWIN");
        console.log("[INITIALIZED] V2 metadata updated");
        console.log("  New Name:", tokenV2.name());
        console.log("  New Symbol:", tokenV2.symbol());

        vm.stopBroadcast();

        // ==========================================
        // PASO 5: VERIFICACIÓN POST-UPGRADE
        // ==========================================
        console.log("\n===========================================");
        console.log("PASO 5: VERIFICACION POST-UPGRADE");
        console.log("===========================================\n");

        bool allChecksPass = true;

        // Verify metadata changed
        console.log("[CHECK] Token Metadata:");
        if (keccak256(bytes(tokenV2.name())) == keccak256(bytes("Twin Token"))) {
            console.log("  [OK] Name changed to:", tokenV2.name());
        } else {
            console.log("  [FAIL] Name is:", tokenV2.name());
            allChecksPass = false;
        }

        if (keccak256(bytes(tokenV2.symbol())) == keccak256(bytes("TWIN"))) {
            console.log("  [OK] Symbol changed to:", tokenV2.symbol());
        } else {
            console.log("  [FAIL] Symbol is:", tokenV2.symbol());
            allChecksPass = false;
        }

        // Verify balances preserved
        console.log("\n[CHECK] Balances Preserved:");
        if (tokenV2.balanceOf(user1) == user1BalanceBefore) {
            console.log("  [OK] user1 balance preserved:", tokenV2.balanceOf(user1));
        } else {
            console.log("  [FAIL] user1 balance changed from", user1BalanceBefore, "to", tokenV2.balanceOf(user1));
            allChecksPass = false;
        }

        if (tokenV2.balanceOf(user2) == user2BalanceBefore) {
            console.log("  [OK] user2 balance preserved:", tokenV2.balanceOf(user2));
        } else {
            console.log("  [FAIL] user2 balance changed");
            allChecksPass = false;
        }

        if (tokenV2.balanceOf(user3) == user3BalanceBefore) {
            console.log("  [OK] user3 balance preserved:", tokenV2.balanceOf(user3));
        } else {
            console.log("  [FAIL] user3 balance changed");
            allChecksPass = false;
        }

        if (tokenV2.totalSupply() == totalSupplyBefore) {
            console.log("  [OK] Total supply preserved:", tokenV2.totalSupply());
        } else {
            console.log("  [FAIL] Total supply changed");
            allChecksPass = false;
        }

        // Verify roles preserved
        console.log("\n[CHECK] Roles Preserved:");
        if (tokenV2.hasRole(DEFAULT_ADMIN_ROLE, deployer)) {
            console.log("  [OK] deployer still has DEFAULT_ADMIN_ROLE");
        } else {
            console.log("  [FAIL] deployer lost DEFAULT_ADMIN_ROLE");
            allChecksPass = false;
        }

        if (tokenV2.hasRole(MINTER_BURNER_ROLE, minter)) {
            console.log("  [OK] minter still has MINTER_BURNER_ROLE");
        } else {
            console.log("  [FAIL] minter lost MINTER_BURNER_ROLE");
            allChecksPass = false;
        }

        if (tokenV2.hasRole(CIRCUIT_BREAKER_ROLE, circuitBreaker)) {
            console.log("  [OK] circuitBreaker still has CIRCUIT_BREAKER_ROLE");
        } else {
            console.log("  [FAIL] circuitBreaker lost CIRCUIT_BREAKER_ROLE");
            allChecksPass = false;
        }

        if (tokenV2.hasRole(DISALLOW_ROLE, disallower)) {
            console.log("  [OK] disallower still has DISALLOW_ROLE");
        } else {
            console.log("  [FAIL] disallower lost DISALLOW_ROLE");
            allChecksPass = false;
        }

        // Verify blacklist preserved
        console.log("\n[CHECK] Blacklist Preserved:");
        if (tokenV2.isDisallowed(user2) == user2DisallowedBefore) {
            console.log("  [OK] user2 still blacklisted:", tokenV2.isDisallowed(user2));
        } else {
            console.log("  [FAIL] user2 blacklist state changed");
            allChecksPass = false;
        }

        if (tokenV2.isDisallowed(user3) == user3DisallowedBefore) {
            console.log("  [OK] user3 not blacklisted:", tokenV2.isDisallowed(user3));
        } else {
            console.log("  [FAIL] user3 blacklist state changed");
            allChecksPass = false;
        }

        // Verify paused state preserved
        console.log("\n[CHECK] Paused State Preserved:");
        if (tokenV2.paused() == isPausedBefore) {
            console.log("  [OK] Token still paused:", tokenV2.paused());
        } else {
            console.log("  [FAIL] Paused state changed");
            allChecksPass = false;
        }

        // Verify forwarder preserved
        console.log("\n[CHECK] Trusted Forwarder Preserved:");
        if (tokenV2.isTrustedForwarder(forwarder)) {
            console.log("  [OK] Forwarder still trusted:", forwarder);
        } else {
            console.log("  [FAIL] Forwarder no longer trusted");
            allChecksPass = false;
        }

        // Final summary
        console.log("\n===========================================");
        console.log("RESUMEN FINAL");
        console.log("===========================================\n");

        if (allChecksPass) {
            console.log("[SUCCESS] TODAS LAS VERIFICACIONES PASARON!");
            console.log("\nUpgrade exitoso:");
            console.log("  - Name: Num Token -> Twin Token");
            console.log("  - Symbol: NUM -> TWIN");
            console.log("  - Balances: PRESERVADOS");
            console.log("  - Roles: PRESERVADOS");
            console.log("  - Blacklist: PRESERVADA");
            console.log("  - Paused State: PRESERVADO");
            console.log("  - Forwarder: PRESERVADO");
        } else {
            console.log("[FAIL] ALGUNAS VERIFICACIONES FALLARON");
            console.log("Revisar los [FAIL] arriba");
        }

        console.log("\n===========================================");
        console.log("ADDRESSES PARA TESTING MANUAL");
        console.log("===========================================\n");
        console.log("Token Proxy:", address(proxy));
        console.log("Beacon:", address(beacon));
        console.log("TwinToken V2 Implementation:", address(twinImpl));
        console.log("Forwarder:", forwarder);
        console.log("\nUsers:");
        console.log("  deployer:", deployer);
        console.log("  user1:", user1);
        console.log("  user2 (blacklisted):", user2);
        console.log("  user3:", user3);
        console.log("  minter:", minter);
        console.log("  circuitBreaker:", circuitBreaker);
        console.log("  disallower:", disallower);
    }
}
