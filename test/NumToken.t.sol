pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "NumToken.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";

contract NumTokenTest is Test {
    bytes32 public constant EIP712_DOMAIN_TYPE_HASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private constant FORWARDREQUEST_TYPEHASH =
        keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)");

    MinimalForwarder forwarder;
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
        forwarder = new MinimalForwarder();
        token = new NumToken("Num ARS", "nuARS", address(forwarder));
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(typeHash, hashedName, hashedVersion);
        _CACHED_THIS = address(this);
        _TYPE_HASH = typeHash;
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
}