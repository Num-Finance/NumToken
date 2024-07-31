// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/NumTokenBrokerage.sol";

address constant USDC = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;
NumToken constant NTST = NumToken(address(0x4ba7AFb4F2925Efb85261737dA1D781F104d2E10));
address constant ORACLE = 0xA6FEe50cD5030847B20957a1E1B0c1B44b203a01;

contract NumTokenBrokerageDeploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        console.log(vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);


        NumTokenBrokerage psm = new NumTokenBrokerage(NTST, IERC20(USDC), IFunctionsConsumer(ORACLE));
        console.log("PSM deployed at", address(psm));
    }
}
