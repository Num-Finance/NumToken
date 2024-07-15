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

        NumToken usdc = NumToken(0xecdd81146db6987F4825e1a8EAC20CC39a3cEB41);
        NumToken netf = NumToken(0x69833E1a6c1CCF983E0dC3Aeac1B884052bb7E32);
        KYCMapper mapper = KYCMapper(0xD2Da604dfFC934ADFa28A248f6a701eAcbdd7B4c);

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

contract VendingMachineAddManager is Script {
  function run() public {
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);

    VendingMachine vending = VendingMachine(0x17cB10FB5ea0d3c5084025F23643f7aD3d369Ef3);
    vending.grantRole(vending.MANAGER_ROLE(), vm.envAddress("VENDING_ADMIN"));

    vm.stopBroadcast();
  }
}

contract ExtraVendingMachine is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address payable defaultadmin = payable(vm.envAddress("DEFAULT_ADMIN_ROLE"));

        NumToken usdc = NumToken(0xC1E1C0Ab645Bd3C3156b20953784992013FDa98d);
        NumToken netf = NumToken(0x112250D431C3d71C2B60DF4804F9cE6CFB682921);
        KYCMapper mapper = KYCMapper(0xD2Da604dfFC934ADFa28A248f6a701eAcbdd7B4c);

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
