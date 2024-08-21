// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "src/pricing/PriceProvider.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./mock/FakeConsumer.sol";

contract PriceProviderTest is Test {
    address alice = address(0x1);
    address bob = address(0x2);
    FakeConsumer consumer;
    PriceProvider providerImpl;
    PriceProvider provider;

    function setUp() public {
        consumer = new FakeConsumer();
        providerImpl = new PriceProvider();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(providerImpl),
            alice,
            abi.encodeCall(
                PriceProvider.initialize,
                (bob, address(consumer), 1 minutes)
            )
        );

        provider = PriceProvider(address(proxy));
        consumer.setResponse(abi.encode(0));
    }

    function test_getPrice() public {
        assertEq(provider.getPrice(), 0);
    }

    function testFail_getPrice_stale() public {
        skip(5 minutes);
        provider.getPrice();
    }

    function test_setTimeTolerance() public {
        vm.prank(bob);
        provider.setTimeTolerance(5 minutes);
    }

    function testFail_setTimeTolerance_unauthorized() public {
        provider.setTimeTolerance(5 minutes);
    }
}
