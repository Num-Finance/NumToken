pragma solidity ^0.8.15;

import "forge-std/script.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "src/NumToken.sol";

contract NumTokenDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        console.log(vm.addr(deployerPrivateKey));

        MinimalForwarder forwarder = MinimalForwarder(vm.envAddress("FORWARDER_ADDRESS"));

        // NOTE: `forwarder` is immutable and can't be changed after deployment.
        //        we're using a MinimalForwarder here which provides basic functionality
        //        for metatransactions - but this scheme does ** NOT ** support upgrades to this
        //        variable. Consider making the forwarder upgradeable?
        NumToken tokenImpl = new NumToken(address(forwarder));

        UpgradeableBeacon beacon = new UpgradeableBeacon(address(tokenImpl));

        BeaconProxy tokenProxy = new BeaconProxy(
            address(beacon), ""
        );

        NumToken token = NumToken(address(tokenProxy));

        /// Deploy a token instance
        NumToken(address(tokenProxy)).initialize(
            "Num ARS",
            "nARS"
        );

        /// Set up roles
        {
            /// MINTER_BURNER_ROLE
            address[] memory minters_burners = vm.envAddress("MINTER_BURNER_ROLE", ",");
            for (uint i = 0; i < minters_burners.length; ++i)
                token.grantRole(
                    token.MINTER_BURNER_ROLE(),
                    minters_burners[i]
                );
        }
        {
            /// DISALLOW_ROLE
            address[] memory disallowers = vm.envAddress("DISALLOW_ROLE", ",");
            for (uint i = 0; i < disallowers.length; ++i)
                token.grantRole(
                    token.DISALLOW_ROLE(),
                    disallowers[i]
                );
        }
        {
            /// CIRCUIT_BREAKER_ROLE
            address[] memory circuitbreakers = vm.envAddress("CIRCUIT_BREAKER_ROLE", ",");
            for (uint i = 0; i < circuitbreakers.length; ++i)
                token.grantRole(
                    token.CIRCUIT_BREAKER_ROLE(),
                    circuitbreakers[i]
                );
        }

        // address defaultadmin = vm.envAddress("DEFAULT_ADMIN_ROLE");
        // token.grantRole(
        //     token.DEFAULT_ADMIN_ROLE(),
        //     defaultadmin
        // );
        //
        //
        // token.renounceRole(
        //     token.DEFAULT_ADMIN_ROLE(),
        //     vm.addr(deployerPrivateKey)
        // );

        vm.stopBroadcast();
    }
}
