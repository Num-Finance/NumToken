// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "src/pricing/PriceProvider.sol";
import "src/pricing/PriceProviderV2.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./mock/FakeConsumer.sol";
import "./mock/FakeChronicle.sol";

contract PriceProviderV2Test is Test {
    address alice = address(0x1);
    address bob = address(0x2);
    FakeConsumer consumer;
    FakeChronicle chronicle;
    PriceProvider providerImpl;
    PriceProviderV2 providerv2Impl;
    PriceProviderV2 provider;

    function setUp() public {
        consumer = new FakeConsumer();
        chronicle = new FakeChronicle();
        providerImpl = new PriceProvider();
        providerv2Impl = new PriceProviderV2();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(providerImpl),
            alice,
            abi.encodeCall(
                PriceProvider.initialize,
                (bob, address(consumer), 1 minutes)
            )
        );

        provider = PriceProviderV2(address(proxy));
        consumer.setResponse(abi.encode(0));
    }

    function test_upgrade() public {
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(provider)));
        vm.prank(alice);
        proxy.upgradeToAndCall(
            address(providerv2Impl),
            abi.encodeCall(
                PriceProviderV2.initializeV2,
                (PriceProviderV2.Source({
                    source: address(chronicle),
                    sourceType: PriceProviderV2.SourceType.ChronicleDataFeed,
                    enabled: true
                }))
            )
        );
    }
    function testFail_upgrade_failsWhenSourceIsntProperlySet() public {
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(provider)));
        vm.prank(alice);
        proxy.upgradeToAndCall(
            address(providerv2Impl),
            abi.encodeCall(
                PriceProviderV2.initializeV2,
                (PriceProviderV2.Source({
                    source: address(chronicle),
                    sourceType: PriceProviderV2.SourceType.ChainlinkFunctionsConsumer,
                    enabled: true
                }))
            )
        );
    }

    modifier upgrade() {
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(payable(address(provider)));
        vm.prank(alice);
        proxy.upgradeToAndCall(
            address(providerv2Impl),
            abi.encodeCall(
                PriceProviderV2.initializeV2,
                (PriceProviderV2.Source({
                    source: address(chronicle),
                    sourceType: PriceProviderV2.SourceType.ChronicleDataFeed,
                    enabled: true
                }))
            )
        );
        _;
    }

    function test_setChainlinkSourceEnabled() public upgrade {
        vm.prank(bob);
        provider.setChainlinkSourceEnabled(false);
    }

    function test_setChronicleSourceEnabled() public upgrade {
        vm.prank(bob);
        provider.setChronicleSourceEnabled(false);
    }

    function testFail_setChainlinkSourceEnabled() public upgrade {
        vm.prank(alice);
        provider.setChainlinkSourceEnabled(false);
    }

    function testFail_setChronicleSourceEnabled() public upgrade {
        vm.prank(alice);
        provider.setChronicleSourceEnabled(false);
    }

    function setConsumerPrice(uint256 price) internal {
        consumer.setResponse(bytes(abi.encodePacked(price)));
    }

    function test_getPrice_bothWork_meanPrice() public upgrade {
        setConsumerPrice(0.1 ether);
        chronicle.setResponse(0.15 ether);

        uint256 reportedPrice = provider.getPrice();

        assertEq(reportedPrice, 0.125 ether);
    }

    function test_getPrice_onlyChainlinkWorks() public upgrade {
        skip(10 minutes);
        setConsumerPrice(0.1 ether);


        uint256 reportedPrice = provider.getPrice();

        assertEq(reportedPrice, 0.1 ether);
    }

    function test_getPrice_onlyChronicleWorks() public upgrade {
        skip(10 minutes);
        chronicle.setResponse(0.15 ether);

        uint256 reportedPrice = provider.getPrice();

        assertEq(reportedPrice, 0.15 ether);
    }

    function test_getPrice_noneWork_stale() public upgrade {
        skip(10 minutes);
        vm.expectRevert(PriceProvider.SourceDataStale.selector);
        provider.getPrice();
    }

    function test_getPrice_noneWork_disabled() public upgrade {
        vm.startPrank(bob);
        provider.setChronicleSourceEnabled(false);
        provider.setChainlinkSourceEnabled(false);
        vm.stopPrank();

        vm.expectRevert(PriceProviderV2.SourceDisabled.selector);
        provider.getPrice();
    }

    function test_getPriceWithStrategy() public upgrade {
        setConsumerPrice(0.1 ether);
        chronicle.setResponse(0.15 ether);

        uint256 reportedPrice = provider.getPriceWithStrategy(
            PriceProviderV2.PriceStrategy.CLFunctionThenFallback);

        assertEq(reportedPrice, 0.125 ether);
    }

    function test_getPriceWithStrategy_unknownStrategy() public upgrade {
        setConsumerPrice(0.1 ether);
        chronicle.setResponse(0.15 ether);

        // NOTE: See low level call gotcha https://book.getfoundry.sh/cheatcodes/expect-revert?highlight=expectRevert#expectrevert
        vm.expectRevert(PriceProviderV2.NoStrategy.selector);
        (bool revertsAsExpected, ) = address(provider).call(
            abi.encodePacked(
                PriceProviderV2.getPriceWithStrategy.selector,
                uint256(20000) // invalid value
            )
        );
        // NOTE: Foundry seems to keep the original `status` value
        //       even though the documentation mentions the cheatcode
        //       changes it.
        assertFalse(revertsAsExpected);
    }

}
