pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "src/TwinToken.sol";
import "src/create2/TwinTokenCreate2Factory.sol";

contract TwinTokenCreate2FactoryTest is Test {
    TwinTokenCreate2Factory factory;
    TwinToken implementation;
    address beacon;

    address deployer = address(0xD3);
    address admin = address(0xAD);
    address beaconOwner = address(0xB0);
    address minter = address(0x111);
    address disallower = address(0x222);
    address breaker = address(0x333);

    bytes32 constant SALT = keccak256("twin.test");

    function _roles() internal view returns (TwinTokenCreate2Factory.Roles memory roles) {
        roles.minters = new address[](1);
        roles.minters[0] = minter;
        roles.disallowers = new address[](1);
        roles.disallowers[0] = disallower;
        roles.breakers = new address[](1);
        roles.breakers[0] = breaker;
    }

    /// @dev Deploys through the deterministic CREATE2 deployer, like forge scripts do with `new X{salt:}`.
    function _create2(bytes32 salt, bytes memory initCode) internal returns (address deployed) {
        (bool ok, bytes memory ret) = CREATE2_FACTORY.call(abi.encodePacked(salt, initCode));
        require(ok, "CREATE2 deployment failed");
        deployed = address(bytes20(ret));
    }

    function _deployAll() internal returns (address factory_, address impl_, address beacon_, address token_) {
        bytes32 salt = keccak256("twin.chains");
        factory_ = _create2(salt, abi.encodePacked(type(TwinTokenCreate2Factory).creationCode, abi.encode(deployer)));
        impl_ = _create2(salt, abi.encodePacked(type(TwinToken).creationCode, abi.encode(address(0))));
        vm.startPrank(deployer);
        beacon_ = TwinTokenCreate2Factory(factory_).deployBeacon(salt, impl_, beaconOwner);
        token_ = TwinTokenCreate2Factory(factory_).deployToken(
            salt, beacon_, "Argentine Peso token", "ARGt", admin, _roles()
        );
        vm.stopPrank();
    }

    function setUp() public {
        factory = new TwinTokenCreate2Factory{salt: SALT}(deployer);
        implementation = new TwinToken{salt: SALT}(address(0));
        vm.prank(deployer);
        beacon = factory.deployBeacon(SALT, address(implementation), beaconOwner);
    }

    function testSameAddressesAcrossChains() public {
        uint256 snapshot = vm.snapshot();
        vm.chainId(42161);
        (address f1, address i1, address b1, address t1) = _deployAll();

        vm.revertTo(snapshot);
        vm.chainId(8453);
        // A different deployer nonce on another chain must not affect the addresses.
        vm.setNonce(deployer, 500);
        (address f2, address i2, address b2, address t2) = _deployAll();

        assertEq(f1, f2);
        assertEq(i1, i2);
        assertEq(b1, b2);
        assertEq(t1, t2);
    }

    function testPredictions() public {
        assertEq(factory.predictBeacon(SALT, address(implementation)), beacon);

        address predicted = factory.predictToken(SALT, beacon, "Argentine Peso token", "ARGt");
        vm.prank(deployer);
        address token = factory.deployToken(SALT, beacon, "Argentine Peso token", "ARGt", admin, _roles());
        assertEq(token, predicted);
    }

    function testBeaconOwnership() public {
        assertEq(UpgradeableBeacon(beacon).owner(), beaconOwner);
        assertEq(UpgradeableBeacon(beacon).implementation(), address(implementation));
    }

    function testTokenRolesAndState() public {
        vm.prank(deployer);
        TwinToken token = TwinToken(
            factory.deployToken(SALT, beacon, "Argentine Peso token", "ARGt", admin, _roles())
        );

        assertEq(token.name(), "Argentine Peso token");
        assertEq(token.symbol(), "ARGt");
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.MINTER_BURNER_ROLE(), minter));
        assertTrue(token.hasRole(token.DISALLOW_ROLE(), disallower));
        assertTrue(token.hasRole(token.CIRCUIT_BREAKER_ROLE(), breaker));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), address(factory)));
        assertFalse(token.hasRole(token.DEFAULT_ADMIN_ROLE(), deployer));

        vm.expectRevert("Initializable: contract is already initialized");
        token.initialize("x", "x");

        vm.prank(minter);
        token.mint(address(this), 1e18);
        assertEq(token.balanceOf(address(this)), 1e18);
    }

    function testOnlyOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        factory.deployBeacon(keccak256("other"), address(implementation), beaconOwner);

        vm.expectRevert("Ownable: caller is not the owner");
        factory.deployToken(SALT, beacon, "Argentine Peso token", "ARGt", admin, _roles());
    }

    function testCannotRedeploySameToken() public {
        vm.startPrank(deployer);
        factory.deployToken(SALT, beacon, "Argentine Peso token", "ARGt", admin, _roles());
        vm.expectRevert();
        factory.deployToken(SALT, beacon, "Argentine Peso token", "ARGt", admin, _roles());
        vm.stopPrank();
    }

    function testZeroAdminReverts() public {
        vm.prank(deployer);
        vm.expectRevert("TwinTokenCreate2Factory: zero admin");
        factory.deployToken(SALT, beacon, "Argentine Peso token", "ARGt", address(0), _roles());
    }
}
