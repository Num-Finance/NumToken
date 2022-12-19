pragma solidity ^0.8.13;

import "forge-std/script.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "src/NumToken.sol";

contract NumTokenDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MinimalForwarder forwarder = new MinimalForwarder();

        NumToken tokenImpl = new NumToken(address(forwarder));

        UpgradeableBeacon beacon = new UpgradeableBeacon(address(tokenImpl));

        BeaconProxy tokenProxy = new BeaconProxy(
            address(beacon), ""
        );

        NumToken token = NumToken(address(tokenProxy));

        /// Deploy a token instance
        NumToken(address(tokenProxy)).initialize(
            "Num ARS",
            "nARS",
            address(forwarder)
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

        token.renounceRole(
            token.DEFAULT_ADMIN_ROLE(),
            vm.addr(deployerPrivateKey)
        );

        vm.stopBroadcast();
    }
}