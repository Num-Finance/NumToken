pragma solidity ^0.8.15;

import "forge-std/script.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "src/VendingMachine.sol";
import "src/NumToken.sol";

contract VendingMachineDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address payable defaultadmin = payable(vm.envAddress("DEFAULT_ADMIN_ROLE"));

        MinimalForwarder forwarder = MinimalForwarder(vm.envAddress("FORWARDER_ADDRESS"));

        // NOTE: `forwarder` is immutable and can't be changed after deployment.
        //        we're using a MinimalForwarder here which provides basic functionality
        //        for metatransactions - but this scheme does ** NOT ** support upgrades to this
        //        variable. Consider making the forwarder upgradeable?
        VendingMachine impl = new VendingMachine(address(forwarder));
        //impl.initialize(0x0, 0x0, 0x0, 0x0);

        UpgradeableBeacon beacon = new UpgradeableBeacon(address(impl));

        beacon.transferOwnership(defaultadmin);

        BeaconProxy vendingProxy = new BeaconProxy(
            address(beacon), ""
        );

        NumToken usdc = NumToken(0xC1E1C0Ab645Bd3C3156b20953784992013FDa98d);
        NumToken netf = NumToken(0x112250D431C3d71C2B60DF4804F9cE6CFB682921);

        VendingMachine vending = VendingMachine(address(vendingProxy));

        /// Deploy a token instance
        vending.initialize(
            usdc,
            netf,
            defaultadmin,
            defaultadmin
        );

        netf.grantRole(netf.MINTER_BURNER_ROLE(), address(vending));

        vm.stopBroadcast();
    }
}

contract VendingMachineUpdate is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        VendingMachine impl = new VendingMachine(vm.envAddress("FORWARDER_ADDRESS"));
        UpgradeableBeacon beacon = UpgradeableBeacon(0x0E507aC7E6981aFe26069853b875c5651Fd2d2Ce);

        beacon.upgradeTo(address(impl));
        vm.stopBroadcast();
    }
}

contract ExtraVendingMachine is Script {
    function run() public {
        UpgradeableBeacon beacon = UpgradeableBeacon(0x0E507aC7E6981aFe26069853b875c5651Fd2d2Ce);
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address payable defaultadmin = payable(vm.envAddress("DEFAULT_ADMIN_ROLE"));

        vm.startBroadcast(deployerPrivateKey);
        BeaconProxy vendingProxy = new BeaconProxy(
            address(beacon), ""
        );

        NumToken usdc = NumToken(0xC1E1C0Ab645Bd3C3156b20953784992013FDa98d);
        NumToken netf = NumToken(0x112250D431C3d71C2B60DF4804F9cE6CFB682921);

        VendingMachine vending = VendingMachine(address(vendingProxy));

        /// Deploy a token instance
        vending.initialize(
            usdc,
            netf,
            defaultadmin,
            defaultadmin
        );

        netf.grantRole(netf.MINTER_BURNER_ROLE(), address(vending));

        vm.stopBroadcast();
    }
}