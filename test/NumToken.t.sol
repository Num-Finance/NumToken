pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "NumToken.sol";
import "gsn/forwarder/Forwarder.sol";
import "gsn/RelayHub.sol";

import "gsn/Penalizer.sol";
import "gsn/StakeManager.sol";

import "gsn/interfaces/IPaymaster.sol";
import "gsn/BasePaymaster.sol";

contract MyPaymaster is BasePaymaster {
}

contract NumTokenTest is Test {
    Forwarder forwarder;
    NumToken token;
    IPaymaster paymaster;
    RelayHub relayhub;
    Penalizer penalizer;
    StakeManager stakeManager;

    address owner = address(type(uint256).max);
    bytes32 alice_pk = keccak256("ALICE'S PRIVATE KEY");
    bytes32 bob_pk   = keccak256("BOB'S PRIVATE KEY");
    address alice    = vm.addr(alice_pk);
    address bob      = vm.addr(bob_pk);


    constructor() {
        forwarder = new Forwarder();
        token = new NumToken("Num ARS", "nuARS", address(forwarder));
        paymaster = new MyPaymaster()
        stakeManager = new StakeManager(
            0,
            0,
            0,
            address(0),
            address(0)
        );
        relayhub = new RelayHub(
            stakeManager, 
            address(0),
            address(0),
            address(0),
            RelayHubConfig({
                maxWorkerCount: 1,
                gasReserve: 100_000,
                postOverhead: 0,
                gasOverhead: 10_000,
                minimumUnstakeDelay: 0,
                devAddress: address(0),
                devFee: 0,
                baseRelayFee: 0,
                pctRelayFee: 0;
            })
        );
    }

    modifier withMint() {
        token.mint(alice, 1_000_000 * 1e18);
        token.mint(bob, 1_000_000 * 1e18);
        _;
    }

    function testMint() public {
        token.mint(alice, 1_000_000 * 1e18);
        token.mint(bob, 1_000_000 * 1e18);
    }

    function testRelay() public withMint {
        ForwardRequest memory req = ForwardRequest({
            from:   alice,
            to:     bob,
            value:  0,
            gas:    1_000_000,
            nonce:  0,
            data:   abi.encodePacked(NumToken.transfer.selector, bob, uint256(1e18)),
            validUntilTime: type(uint256).max
        });

        vm.sign(
            alice_pk,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keccak256()
                )
            )
        )
    }
}