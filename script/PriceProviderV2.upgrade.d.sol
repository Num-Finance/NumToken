// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "src/pricing/PriceProviderV2.sol";

contract PriceProviderV2Upgrade is Script {
    function run() public {
        address chronicleFeed = vm.parseAddress(vm.prompt("Insert the Chronicle Feed adress"));
        TransparentUpgradeableProxy proxy = TransparentUpgradeableProxy(
            payable(vm.parseAddress(
                vm.prompt("Insert the proxy's address")
            ))
        );
        PriceProviderV2 impl = new PriceProviderV2();
        proxy.upgradeToAndCall(address(impl), abi.encodeCall(PriceProviderV2.initializeV2, (PriceProviderV2.Source({
            source: chronicleFeed,
            sourceType: PriceProviderV2.SourceType.ChronicleDataFeed,
            enabled: true
        }))));

        console.log(address(proxy));
    }
}
