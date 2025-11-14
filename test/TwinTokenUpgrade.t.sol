// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import "src/NumToken.sol";
import "src/TwinToken.sol";

/**
 * @title TwinTokenUpgradeTest
 * @notice Tests para verificar que el upgrade de NumToken a TwinToken funcione correctamente
 *
 * Este test verifica:
 * 1. Deployment del setup completo (Beacon + Proxy + NumToken V1)
 * 2. Upgrade a TwinToken (V2)
 * 3. Preservación de storage (balances, roles, paused state)
 * 4. Cambio de nombre y símbolo
 * 5. Funcionalidad post-upgrade
 */
contract TwinTokenUpgradeTest is Test {
    // Contratos
    NumToken public tokenV1;
    TwinToken public tokenV2Impl;
    TwinToken public tokenV2;
    UpgradeableBeacon public beacon;
    BeaconProxy public proxy;

    // Addresses
    address public owner;
    address public minter;
    address public user1;
    address public user2;
    address public forwarder;

    // Constants
    string constant INITIAL_NAME = "Num Token";
    string constant INITIAL_SYMBOL = "NUM";
    string constant NEW_NAME = "Twin Token";
    string constant NEW_SYMBOL = "TWIN";
    uint8 constant DECIMALS = 18;

    // Roles
    bytes32 public constant MINTER_BURNER_ROLE = keccak256("MINTER_BURNER_ROLE");
    bytes32 public constant CIRCUIT_BREAKER_ROLE = keccak256("CIRCUIT_BREAKER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function setUp() public {
        // Setup addresses
        owner = address(this);
        minter = makeAddr("minter");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        forwarder = makeAddr("forwarder");

        console.log("=== SETUP: Deploying NumToken V1 ===");

        // 1. Deploy implementation V1
        NumToken tokenImpl = new NumToken(forwarder);
        console.log("NumToken V1 Implementation:", address(tokenImpl));

        // 2. Deploy Beacon pointing to V1
        beacon = new UpgradeableBeacon(address(tokenImpl));
        console.log("Beacon:", address(beacon));

        // 3. Deploy BeaconProxy
        bytes memory initData = abi.encodeWithSelector(
            NumToken.initialize.selector,
            INITIAL_NAME,
            INITIAL_SYMBOL,
            DECIMALS
        );
        proxy = new BeaconProxy(address(beacon), initData);
        console.log("BeaconProxy:", address(proxy));

        // 4. Cast proxy to NumToken
        tokenV1 = NumToken(address(proxy));

        // 5. Grant roles
        tokenV1.grantRole(MINTER_BURNER_ROLE, minter);

        console.log("\n=== SETUP: Initial State ===");
        console.log("Name:", tokenV1.name());
        console.log("Symbol:", tokenV1.symbol());
        console.log("Decimals:", tokenV1.decimals());
        console.log("Total Supply:", tokenV1.totalSupply());
    }

    function test_InitialState() public view {
        assertEq(tokenV1.name(), INITIAL_NAME);
        assertEq(tokenV1.symbol(), INITIAL_SYMBOL);
        assertEq(tokenV1.decimals(), DECIMALS);
        assertEq(tokenV1.totalSupply(), 0);
        assertTrue(tokenV1.isTrustedForwarder(forwarder));
    }

    function test_UpgradePreservesBalances() public {
        // 1. Mint tokens to users
        console.log("\n=== Minting tokens before upgrade ===");
        vm.startPrank(minter);
        tokenV1.mint(user1, 1000e18);
        tokenV1.mint(user2, 2000e18);
        vm.stopPrank();

        uint256 user1BalanceBefore = tokenV1.balanceOf(user1);
        uint256 user2BalanceBefore = tokenV1.balanceOf(user2);
        uint256 totalSupplyBefore = tokenV1.totalSupply();

        console.log("User1 balance:", user1BalanceBefore);
        console.log("User2 balance:", user2BalanceBefore);
        console.log("Total supply:", totalSupplyBefore);

        // 2. Upgrade to V2
        _upgradeToV2();

        // 3. Verify balances preserved
        console.log("\n=== Verifying balances after upgrade ===");
        assertEq(tokenV2.balanceOf(user1), user1BalanceBefore, "User1 balance should be preserved");
        assertEq(tokenV2.balanceOf(user2), user2BalanceBefore, "User2 balance should be preserved");
        assertEq(tokenV2.totalSupply(), totalSupplyBefore, "Total supply should be preserved");

        console.log("[OK] Balances preserved!");
    }

    function test_UpgradeChangesNameAndSymbol() public {
        // 1. Verify initial state
        assertEq(tokenV1.name(), INITIAL_NAME);
        assertEq(tokenV1.symbol(), INITIAL_SYMBOL);

        // 2. Upgrade to V2
        _upgradeToV2();

        // 3. Verify name and symbol changed
        console.log("\n=== Verifying name and symbol change ===");
        assertEq(tokenV2.name(), NEW_NAME, "Name should be updated");
        assertEq(tokenV2.symbol(), NEW_SYMBOL, "Symbol should be updated");

        console.log("New name:", tokenV2.name());
        console.log("New symbol:", tokenV2.symbol());
        console.log("[OK] Name and symbol updated!");
    }

    function test_UpgradePreservesRoles() public {
        // 1. Verify roles before upgrade
        assertTrue(tokenV1.hasRole(DEFAULT_ADMIN_ROLE, owner), "Owner should have admin role");
        assertTrue(tokenV1.hasRole(MINTER_BURNER_ROLE, minter), "Minter should have minter role");

        // 2. Upgrade to V2
        _upgradeToV2();

        // 3. Verify roles preserved
        console.log("\n=== Verifying roles preserved ===");
        assertTrue(tokenV2.hasRole(DEFAULT_ADMIN_ROLE, owner), "Owner should still have admin role");
        assertTrue(tokenV2.hasRole(MINTER_BURNER_ROLE, minter), "Minter should still have minter role");

        console.log("[OK] Roles preserved!");
    }

    function test_UpgradePreservesTrustedForwarder() public {
        // 1. Verify forwarder before upgrade
        assertTrue(tokenV1.isTrustedForwarder(forwarder), "Forwarder should be trusted before upgrade");

        // 2. Upgrade to V2
        _upgradeToV2();

        // 3. Verify forwarder preserved
        console.log("\n=== Verifying trusted forwarder preserved ===");
        assertTrue(tokenV2.isTrustedForwarder(forwarder), "Forwarder should still be trusted after upgrade");

        console.log("[OK] Trusted forwarder preserved!");
    }

    function test_UpgradePreservesPausedState() public {
        // 1. Grant circuit breaker role and pause
        tokenV1.grantRole(CIRCUIT_BREAKER_ROLE, owner);
        tokenV1.togglePause(); // This will pause
        assertTrue(tokenV1.paused(), "Token should be paused");

        // 2. Upgrade to V2
        _upgradeToV2();

        // 3. Verify paused state preserved
        console.log("\n=== Verifying paused state preserved ===");
        assertTrue(tokenV2.paused(), "Token should still be paused after upgrade");

        // 4. Unpause and verify functionality
        tokenV2.togglePause(); // This will unpause
        assertFalse(tokenV2.paused(), "Token should be unpaused");

        console.log("[OK] Paused state preserved!");
    }

    function test_V2FunctionalityAfterUpgrade() public {
        // 1. Mint some tokens before upgrade
        vm.prank(minter);
        tokenV1.mint(user1, 1000e18);

        // 2. Upgrade to V2
        _upgradeToV2();

        // 3. Test minting after upgrade
        console.log("\n=== Testing functionality after upgrade ===");
        vm.prank(minter);
        tokenV2.mint(user2, 500e18);

        assertEq(tokenV2.balanceOf(user2), 500e18, "Minting should work after upgrade");

        // 4. Test transfers
        vm.prank(user1);
        tokenV2.transfer(user2, 100e18);

        assertEq(tokenV2.balanceOf(user1), 900e18, "Transfer should work - sender");
        assertEq(tokenV2.balanceOf(user2), 600e18, "Transfer should work - receiver");

        // 5. Test burning
        vm.prank(minter);
        tokenV2.burn(user1, 100e18);

        assertEq(tokenV2.balanceOf(user1), 800e18, "Burning should work");

        console.log("[OK] All functionality working after upgrade!");
    }

    function test_CannotInitializeV2Twice() public {
        // 1. Upgrade to V2 (calls initializeV2 once)
        _upgradeToV2();

        // 2. Try to call initializeV2 again - should revert
        console.log("\n=== Testing reinitialize protection ===");
        vm.expectRevert();
        tokenV2.initializeV2("Another Name", "ANOTHER");

        console.log("[OK] Cannot initialize V2 twice!");
    }

    function test_BeaconPointsToNewImplementation() public {
        // 1. Get initial implementation
        address implBefore = beacon.implementation();
        console.log("\n=== Verifying beacon upgrade ===");
        console.log("Implementation before:", implBefore);

        // 2. Deploy V2 implementation
        tokenV2Impl = new TwinToken(forwarder);
        console.log("New implementation deployed:", address(tokenV2Impl));

        // 3. Upgrade beacon
        beacon.upgradeTo(address(tokenV2Impl));

        // 4. Verify beacon points to new implementation
        address implAfter = beacon.implementation();
        console.log("Implementation after:", implAfter);

        assertEq(implAfter, address(tokenV2Impl), "Beacon should point to new implementation");
        assertFalse(implAfter == implBefore, "Implementation should have changed");

        console.log("[OK] Beacon upgraded successfully!");
    }

    function test_OnlyOwnerCanUpgradeBeacon() public {
        // 1. Deploy V2 implementation
        tokenV2Impl = new TwinToken(forwarder);

        // 2. Try to upgrade as non-owner - should revert
        console.log("\n=== Testing upgrade access control ===");
        vm.prank(user1);
        vm.expectRevert();
        beacon.upgradeTo(address(tokenV2Impl));

        console.log("[OK] Only owner can upgrade beacon!");
    }

    function test_TransfersWorkAfterUpgrade() public {
        // 1. Mint tokens
        vm.prank(minter);
        tokenV1.mint(user1, 1000e18);

        // 2. Transfer before upgrade
        vm.prank(user1);
        tokenV1.transfer(user2, 100e18);

        assertEq(tokenV1.balanceOf(user2), 100e18);

        // 3. Upgrade to V2
        _upgradeToV2();

        // 4. Transfer after upgrade
        console.log("\n=== Testing transfers after upgrade ===");
        vm.prank(user1);
        tokenV2.transfer(user2, 200e18);

        assertEq(tokenV2.balanceOf(user1), 700e18);
        assertEq(tokenV2.balanceOf(user2), 300e18);

        console.log("[OK] Transfers work after upgrade!");
    }

    // Helper function to upgrade to V2
    function _upgradeToV2() internal {
        console.log("\n=== Upgrading to TwinToken V2 ===");

        // 1. Deploy V2 implementation
        tokenV2Impl = new TwinToken(forwarder);
        console.log("TwinToken V2 deployed:", address(tokenV2Impl));

        // 2. Upgrade beacon
        beacon.upgradeTo(address(tokenV2Impl));
        console.log("Beacon upgraded to V2");

        // 3. Cast proxy to TwinToken
        tokenV2 = TwinToken(address(proxy));

        // 4. Initialize V2 with new name and symbol
        tokenV2.initializeV2(NEW_NAME, NEW_SYMBOL);
        console.log("V2 initialized with new metadata");
        console.log("New name:", tokenV2.name());
        console.log("New symbol:", tokenV2.symbol());
    }
}
