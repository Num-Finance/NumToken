pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "src/TwinToken.sol";

/**
 * @title TwinTokenDeploy
 * @author Twin Finance
 * @notice This script deploys a TwinToken contract for first time.
 */
contract TwinTokenScript is Script {
    function run() external {
        //0x8A791620dd6260079BF849Dc5567aDC3F2FdC318
        //0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
        
        address tokenAddress = address(0x8A791620dd6260079BF849Dc5567aDC3F2FdC318);
        string memory newName = "Real Brasilero";
        string memory newSymbol = "tBRL";

        TwinToken token = TwinToken(tokenAddress);

        console.log("TwinToken:", tokenAddress);
        console.log("Current name:", token.name());
        console.log("Current symbol:", token.symbol());

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        uint256 notDefultAdminPrivateKey = vm.envUint("NOT_DEFAULT_ADMIN_PRIVATE_KEY");

        /*vm.startBroadcast(deployerPrivateKey);

        token.setName(newName);
        token.setSymbol(newSymbol);

        vm.stopBroadcast();

        console.log("Updated name:", token.name());
        console.log("Updated symbol:", token.symbol());

        vm.startBroadcast(notDefultAdminPrivateKey);

        token.setName("New Name");
        token.setSymbol("New Symbol");

        vm.stopBroadcast();

        console.log("Not changed name:", token.name());
        console.log("Not changed symbol:", token.symbol());*/

    }
}
