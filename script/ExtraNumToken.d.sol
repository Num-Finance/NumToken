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
        address beacon;

        {
            string memory jsonPath = string(abi.encodePacked(
                "./broadcast/NumToken.d.sol/",
                vm.toString(block.chainid),
                "/run-latest.json"
            ));
            string memory BeaconJson = string(vm.readFile(jsonPath));

            beacon = abi.decode(vm.parseJson(BeaconJson, "transactions[1].contractAddress"), (address));
        }

        BeaconProxy tokenProxy = new BeaconProxy(
            address(beacon), ""
        );

        string memory name = vm.envString("name");
        string memory symbol = vm.envString("symbol");

        NumToken token = NumToken(address(tokenProxy));

        /// Deploy a token instance
        NumToken(address(tokenProxy)).initialize(
            name,
            symbol
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

        console.log(string(abi.encodePacked(
            name,
            " deployed to ",
            vm.toString(address(tokenProxy))
        )));
    }
}