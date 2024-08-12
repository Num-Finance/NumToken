// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../src/NumTokenBrokerage.sol";

import "./PriceProvider.d.sol";

address constant USDC = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;
NumToken constant NTST = NumToken(address(0x4ba7AFb4F2925Efb85261737dA1D781F104d2E10));
address constant ORACLE = 0x56fB8187F3d6B8e26dF840f419FbB2901B588399;

contract NumTokenBrokerageDeploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        console.log(vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);


        NumTokenBrokerage psm = new NumTokenBrokerage(NTST, IERC20(USDC), PriceProvider(ORACLE));
        console.log("PSM deployed at", address(psm));
    }
}
