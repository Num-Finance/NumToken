pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "src/NumToken.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";

contract NumTokenTest is Test {
    bytes32 public constant EIP712_DOMAIN_TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private constant FORWARDREQUEST_TYPEHASH =
        keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)");

    MinimalForwarder forwarder;
    NumToken token;

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
        token = new NumToken("Num ARS", "nARS", address(forwarder));
    }

    function testMetadata() public {
        assertEq(
            token.name(), "Num ARS"
        );
        assertEq(
            token.symbol(), "nARS"
        );
    }

    modifier withMint() {
        token.mint(alice, 1_000_000 * 1e18);
        token.mint(bob, 1_000_000 * 1e18);
        _;
    }

    /*
    function testRelay() public withMint {
        ForwardRequest memory req = ForwardRequest({
            from:   alice,
            to:     address(token),
            value:  0,
            gas:    1_000_000,
            nonce:  forwarder.getNonce(alice),
            data:   abi.encodePacked(NumToken.transfer.selector, bob, uint256(1e18)),
            validUntilTime: type(uint256).max
        });

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            alice_pk,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    EIP712_DOMAIN_TYPE_HASH,
                    keccak256(
                        abi.encodePacked(
                            FORWARDREQUEST_TYPEHASH,
                            uint256(uint160(req.from)),
                            uint256(uint160(req.to)),
                            req.value,
                            req.gas,
                            req.nonce,
                            keccak256(req.data),
                            req.validUntilTime,
                            suffixData
                        )
                    )
                )
            )
        );

        forwarder.execute(
            req,
            EIP_DOMAIN_SEPARATOR,
            TRANSFER_REQUEST_TYPE_HASH,
            bytes(),
            abi.encodePacked(
                r,
                s,
                uint256(v)
            )
        );
    }
    */

    function testMintBurn() public {
        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        vm.prank(alice);
        token.mint(bob, 1e18);
    }

    function testFailMintBurn() public {
        // alice should be the only one able to mint
        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        vm.prank(bob);
        token.mint(bob, 1e18);
    }

    function testTaxSetting() public {
        token.grantRole(token.TAX_ROLE(), alice);
        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        vm.startPrank(alice);
        token.setTaxBasisPoints(0);
        token.mint(bob, 100e18);
        token.setTaxCollector(alice);
        vm.stopPrank();
    }

    function testTaxCalculation() public {
        token.grantRole(token.TAX_ROLE(), alice);
        token.grantRole(token.MINTER_BURNER_ROLE(), alice);

        // setup tax collector, taxBasisPoints == 0
        vm.startPrank(alice);
        token.mint(bob, 10e18);
        token.setTaxCollector(alice);
        vm.stopPrank();

        vm.prank(bob);
        token.transfer(carl, 1e18);

        assertEq(
            token.balanceOf(carl), 1e18, "cb"
        );

        // Set taxBasisPoints to 10, 0.1%
        vm.prank(alice);
        token.setTaxBasisPoints(10);

        vm.prank(bob);
        token.transfer(dani, 1e18);

        assertEq(
            token.balanceOf(dani), 1e18 - 1e15, "db"
        );
        assertEq(
            token.balanceOf(bob), 8e18, "bb"
        );
        assertEq(
            token.balanceOf(alice), 1e15, "ab"
        );
    }

    function testDisallowList() public {
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
}