// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import "src/pricing/PriceProvider.sol";

address constant AMOY_FUNCTIONS_CONSUMER = 0xA6FEe50cD5030847B20957a1E1B0c1B44b203a01;

contract PriceProviderDeploy is Script {
    function run() public {
        require(block.chainid == 80002, "use polygon amoy");
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        console.log("Deploying from", vm.addr(deployerPk));
        address ppAdmin = vm.parseAddress(vm.prompt("Insert price provider admin address - CANNOT BE THE DEPLOYER"));
        vm.startBroadcast(deployerPk);
        PriceProvider impl = new PriceProvider();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(impl),
            vm.addr(deployerPk),
            abi.encodeCall(
                PriceProvider.initialize,
                (ppAdmin, AMOY_FUNCTIONS_CONSUMER, 15 minutes)
            )
        );
        vm.stopBroadcast();

        console.log("Implementation at", address(impl));
        console.log("Proxy at", address(proxy));
    }
}
