pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "src/NumToken.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

contract NumTokenTest is Test {
    bytes32 public constant EIP712_DOMAIN_TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private constant FORWARDREQUEST_TYPEHASH =
        keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)");

    MinimalForwarder forwarder;
    NumToken tokenImpl;
    UpgradeableBeacon beacon;
    BeaconProxy tokenProxy;

    bytes32 alice_pk = keccak256("ALICE'S PRIVATE KEY");
    bytes32 bob_pk   = keccak256("BOB'S PRIVATE KEY");
    bytes32 carl_pk   = keccak256("CARL'S PRIVATE KEY");
    bytes32 dani_pk   = keccak256("DANI'S PRIVATE KEY");
    address alice    = vm.addr(uint256(alice_pk));
    address bob      = vm.addr(uint256(bob_pk));
    address carl     = vm.addr(uint256(carl_pk));
    address dani     = vm.addr(uint256(dani_pk));


    function setUp() public {
        forwarder = new MinimalForwarder();
        tokenImpl = new NumToken(address(forwarder));

        beacon = new UpgradeableBeacon(address(tokenImpl));

        tokenProxy = new BeaconProxy(
            address(beacon), ""
            // abi.encodePacked(
            //     NumToken.initialize.selector,
            //     "Num ARS",
            //     "nARS"
            // )
        );

        NumToken token = NumToken(address(tokenProxy));
        token.initialize("Num ARS", "nARS");
    }

    function testMetadata() public {
        NumToken token = NumToken(address(tokenProxy));

        assertEq(
            token.name(), "Num ARS"
        );
        assertEq(
            token.symbol(), "nARS"
        );
    }

    modifier withMint() {
        NumToken token = NumToken(address(tokenProxy));
        token.grantRole(token.MINTER_BURNER_ROLE(), address(this));

        token.mint(alice, 1_000_000 * 1e18);
        token.mint(bob, 1_000_000 * 1e18);
        _;
    }

    function relayCall(
        address from,
        bytes32 from_pk,
        address to,
        uint256 value,
        uint256 gas,
        bytes memory data
        ) internal returns (bool, bytes memory)
    {
        MinimalForwarder.ForwardRequest memory req = MinimalForwarder.ForwardRequest({
            from:   from,
            to:     to,
            value:  value,
            gas:    gas,
            nonce:  forwarder.getNonce(from),
            data:   data
        });

        bytes32 forwardRequestHash = keccak256(
            abi.encode(
                FORWARDREQUEST_TYPEHASH,
                req.from,
                req.to,
                req.value,
                req.gas, 
                req.nonce,
                keccak256(req.data)
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPE_HASH,
                keccak256(bytes("MinimalForwarder")),
                keccak256(bytes("0.0.1")),
                block.chainid,
                address(forwarder)
            )
        );

        bytes32 typedDataHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                forwardRequestHash
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(from_pk),
            typedDataHash
        );

        return forwarder.execute(
            req,
            abi.encodePacked(
                r,
                s,
                v
            )
        );
    }

    function testMintBurn() public {
        NumToken token = NumToken(address(tokenProxy));

        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        vm.startPrank(alice);
        token.mint(bob, 1e18);
        token.burn(bob, 1e18);
        vm.stopPrank();
    }

    function testFailMintBurn() public {
        NumToken token = NumToken(address(tokenProxy));

        // alice should be the only one able to mint
        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        vm.prank(bob);
        token.mint(bob, 1e18);
    }

    function testDisallowList() public {
        NumToken token = NumToken(address(tokenProxy));

        token.grantRole(token.DISALLOW_ROLE(), alice);

        vm.prank(alice);
        token.disallow(bob);

        assertEq(
            token.isDisallowed(bob), true
        );

        vm.prank(alice);
        token.allow(bob);

        assertEq(
            token.isDisallowed(bob), false
        );
    }

    function testCannotTransferWhenDisallowed() public {
        NumToken token = NumToken(address(tokenProxy));

        token.grantRole(token.DISALLOW_ROLE(), alice);
        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        vm.prank(alice);
        token.mint(bob, 10e18);

        vm.prank(bob);
        token.transfer(carl, 1e18);

        vm.prank(alice);
        token.disallow(bob);

        vm.prank(bob);
        vm.expectRevert();
        token.transfer(carl, 1e18);
    }

    function testPause() public {
        NumToken token = NumToken(address(tokenProxy));

        token.grantRole(token.CIRCUIT_BREAKER_ROLE(), alice);
        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        vm.prank(alice);
        token.mint(bob, 10e18);

        vm.prank(bob);
        token.transfer(carl, 1e18);

        vm.prank(alice);
        token.togglePause();

        vm.prank(bob);
        vm.expectRevert();
        token.transfer(carl, 1e18);

        vm.startPrank(alice);
        token.burn(carl, 1e18);
        token.mint(bob, 1e18);
        vm.stopPrank();

        assertEq(
            token.paused(), true
        );

        assertEq(
            token.balanceOf(carl), 0
        );
    }

    /** Relay tests **/
    function testRelayTransfer() public withMint {
        relayCall(
            alice,
            alice_pk,
            address(tokenProxy),
            0,
            1_000_000,
            abi.encodePacked(IERC20Upgradeable.transfer.selector, bob, uint256(1e18))
        );
    }

    function testRelayMint() public {
        NumToken token = NumToken(address(tokenProxy));

        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        bool success;

        (success, ) = relayCall(
            alice,
            alice_pk,
            address(token),
            0,
            1_000_000,
            abi.encodePacked(
                NumToken.mint.selector,
                abi.encode(dani),
                type(uint256).max
            )
        );

        assertEq(success, true);

        (success, ) = relayCall(
            bob,
            bob_pk,
            address(token),
            0,
            1_000_000,
            abi.encodePacked(
                NumToken.mint.selector,
                abi.encode(bob),
                uint256(1338)
            )
        );

        assertEq(success, false);
    }

    function testRelayPause() public {
        NumToken token = NumToken(address(tokenProxy));

        token.grantRole(token.CIRCUIT_BREAKER_ROLE(), alice);

        bool success;

        (success, ) = relayCall(
            alice,
            alice_pk,
            address(token),
            0,
            1_000_000,
            abi.encodePacked(
                NumToken.togglePause.selector
            )
        );

        assertEq(success, true);

       (success, ) = relayCall(
            bob,
            bob_pk,
            address(token),
            0,
            1_000_000,
            abi.encodePacked(
                NumToken.togglePause.selector
            )
        ); 

        assertEq(success, false);
    }

    function testRelayDisallowList() public {
        NumToken token = NumToken(address(tokenProxy));

        token.grantRole(token.DISALLOW_ROLE(), alice);

       bool success;

        (success, ) = relayCall(
            alice,
            alice_pk,
            address(token),
            0,
            1_000_000,
            abi.encodePacked(
                NumToken.disallow.selector,
                abi.encode(carl)
            )
        );

        assertEq(success, true);

       (success, ) = relayCall(
            alice,
            alice_pk,
            address(token),
            0,
            1_000_000,
            abi.encodePacked(
                NumToken.allow.selector,
                abi.encode(dani)
            )
        ); 

        assertEq(success, true); 

        (success, ) = relayCall(
            bob,
            bob_pk,
            address(token),
            0,
            1_000_000,
            abi.encodePacked(
                NumToken.disallow.selector,
                abi.encode(dani)
            )
        ); 

        assertEq(success, false); 
    }
}