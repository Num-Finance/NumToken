pragma solidity ^0.8.15;

import "forge-std/script.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "src/VendingMachine.sol";
import "src/NumToken.sol";
import "src/KYCMapper.sol";

contract VendingMachineDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address payable defaultadmin = payable(vm.envAddress("DEFAULT_ADMIN_ROLE"));

        NumToken usdc = NumToken(0xC1E1C0Ab645Bd3C3156b20953784992013FDa98d);
        NumToken netf = NumToken(0xDF4DDe37bdbe76Ac7af1B068877C7901f254A211);
        KYCMapper mapper = KYCMapper(0x6187067a11FeD469Db792546398Ef976cfE4a81f);

        VendingMachine vending = new VendingMachine(
            usdc,
            netf,
            mapper,
            defaultadmin,
            defaultadmin
        );

        netf.grantRole(netf.MINTER_BURNER_ROLE(), address(vending));

        vm.stopBroadcast();
    }
}

contract ExtraVendingMachine is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address payable defaultadmin = payable(vm.envAddress("DEFAULT_ADMIN_ROLE"));

        NumToken usdc = NumToken(0xC1E1C0Ab645Bd3C3156b20953784992013FDa98d);
        NumToken netf = NumToken(0x112250D431C3d71C2B60DF4804F9cE6CFB682921);
        KYCMapper mapper = KYCMapper(0x6187067a11FeD469Db792546398Ef976cfE4a81f);

        VendingMachine vending = new VendingMachine(
            usdc,
            netf,
            mapper,
            defaultadmin,
            defaultadmin
        );

        netf.grantRole(netf.MINTER_BURNER_ROLE(), address(vending));

        vm.stopBroadcast();
    }
}
