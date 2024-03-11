pragma solidity ^0.8.15;

import "forge-std/script.sol";
import "src/KYCMapper.sol";


contract KYCMapperDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address payable defaultadmin = payable(vm.envAddress("DEFAULT_ADMIN_ROLE"));

        KYCMapper mapper = new KYCMapper();

        /// Deploy a token instance
        mapper.grantRole(
            mapper.KYC_ADMIN_ROLE(),
            defaultadmin
        );

        console.log("Deployed mapper at", address(mapper));

        vm.stopBroadcast();
    }
}

contract KYCMapperAddAdmin is Script {
    function run() external {
        KYCMapper mapper = KYCMapper(0x6187067a11FeD469Db792546398Ef976cfE4a81f);

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        mapper.grantRole(
            keccak256("KYC_ADMIN_ROLE"),
            vm.envAddress("KYC_ADMIN")
        );

        vm.stopBroadcast();
    }
}

contract KYCMapperWhitelist is Script {
    function run() external {
        KYCMapper mapper = KYCMapper(0x6187067a11FeD469Db792546398Ef976cfE4a81f);

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        mapper.setAddressWhitelisted(0x2Df60994237608260870584D5895Eb84b0614316, true);
        vm.stopBroadcast();
    }
}
