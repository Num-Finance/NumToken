pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "openzeppelin/metatx/MinimalForwarder.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "src/TwinToken.sol";

/**
 * @title TwinTokenRolesScript
 * @author Twin Finance
 * @notice This script sets up roles for a TwinToken contract.
 */
contract TwinTokenRolesScript is Script {
    function checkAdminRole(TwinToken token, address wallet) internal view returns (bool) {
        return token.hasRole(token.DEFAULT_ADMIN_ROLE(), wallet);
    }

    function grantRoles(TwinToken token, address wallet) internal {
        // DEFAULT_ADMIN_ROLE
        token.grantRole(
            token.DEFAULT_ADMIN_ROLE(),
            wallet
        );
        
        /*
        // MINTER_BURNER_ROLE
        token.grantRole(
            token.MINTER_BURNER_ROLE(),
            wallet
        );
    
        // DISALLOW_ROLE
        token.grantRole(
            token.DISALLOW_ROLE(),
            wallet
        );
    
        // CIRCUIT_BREAKER_ROLE
        token.grantRole(
            token.CIRCUIT_BREAKER_ROLE(),
            wallet
        );*/
    }

    function revokeRoles(TwinToken token, address wallet) internal {
        // Revoke roles from deployer wallet
        token.revokeRole(
            token.MINTER_BURNER_ROLE(),
            wallet
        );
        
        token.revokeRole(
            token.DISALLOW_ROLE(),
            wallet
        );
    
        token.revokeRole(
            token.CIRCUIT_BREAKER_ROLE(),
            wallet
        );
    }

    function renounceAdminRole(TwinToken token, address wallet) internal {
        token.renounceRole(
            token.DEFAULT_ADMIN_ROLE(),
            wallet
        );
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    
        /*
        // Roles
        0x0000000000000000000000000000000000000000000000000000000000000000
        0x7e6b58bc1470e1fc07bc9b21e0435be41fdc30ede9591781476a8d169a265492
        0x0726c8258b9de94ffd154f603b315240b42c2424db4dbb983018049e43a2df1a
        0xcfd53186d792f1ec9d0679afc2dc3ffc86fc31fe1e0f342b838eb6c3eade62b3

        0x3F5C58f0b2400Cd82eA7ea6c3B5794a1228f3Df9
        */

        // Base TwinToken address
        /*address[10] memory tokens = [
            0xf016413834E6D1A14F3D628B11D6Ef725a6bdbDD, // ARGt
            0xFEE29845569570F8e0119291dff77B7b93283aaB, // BRAt
            0xD70ad085684b2A9f4B5d54D7BDB2ecA37a273216, // COLt
            0xD09ABA2969B822d66DC4Bc3bB58eE520Bcf9f0C3, // PERt
            0x59863989d080B22476DB95656d0C3CC18be92214, // MEXt
            0x95ef2370166b250e7CE3b8F236c7e7E9feD12c2e, // CHLt
            0x1d2E8C1Fe82ab2AD8dc43eD98A2F507Dfb5b4995, // BOLt
            0x9d5855C52e2c3d07DC5120789F484E6d1D32A985, // PRYt
            0xC5F7EdbEDb4c61bC351dBb69D12077aF491270Cb, // URYt
            0xa1685112Cb61210ab2a929C9Ce370A4FD381D8Be  // VENt
        ];*/
        
        // Polygon Mainnet TwinToken addresses
        /*address[10] memory tokens = [
            0x50464bE58912745447E24EB3bbDedcee10D3E056, // revoke admin
            0x59863989d080B22476DB95656d0C3CC18be92214  
            0xfa658f62CA6cacaa769035AdBcbeD9Bf75f9f72D, // revoke roles with multisig
            0x1EA02bA45fC146F534b371c49fBB2a4c86dce93d, // revoke roles
            0x53Bd6E8Af3DA05781afC98729378424f66c9Da52, // revoke roles
            0xb9A848a8E1AFf1a16A27F1AD3B66D873d5C38D62, // revoke roles
            0x20ECA820D3cd00ed9C9f2861Cdf6429baCD8ed55, // revoke roles
            0x5884fFD7597E05493f83fF44E96beFd4F0fe474d, // revoke roles
            0xaEf12aff8054128D5d3dD848F6d645854e0Cd426, // revoke roles
            0x0b60faFc79761a28dB657707BaEbb34Fc6589B73 // revoke roles
        ];*/

       // Arbitrum One TwinToken addresses
        /*address[10] memory tokens = [
            0x59863989d080B22476DB95656d0C3CC18be92214,
            0xC4ed6Aba5373D78E160F4df39e011F078Be54df8,
            0xe8dbC4680235cCAeFf48e4C0B0EaceeBb89E5e17,
            0xa16d5DB80A45157E0e451750B81FF0CC0b61d558,
            0x899438713f62B04d6CD8e8709986F7256fB6E3d9,
            0xb96aA6babCcD738d6644ADd4912fE5eFbEBF5a25,
            0x1edF5E61B6a4Fe19FEf3A695328F61aAa07728eA,
            0x6Bb883b61D58f3531cd2e15563F2CDd0E9B24E32,
            0x2eCC8c60C881436D43b9AE8EEC7bc226D5404E71,
            0x8c4106beE19CB995abab20f3De6Ba9DF9CF9A17f
        ];*/

        // Ethereum TwinToken addresses
        address[10] memory tokens = [
            0x59863989d080B22476DB95656d0C3CC18be92214,
            0xFEE29845569570F8e0119291dff77B7b93283aaB,
            0xf016413834E6D1A14F3D628B11D6Ef725a6bdbDD,
            0x6d937FF125CAeb81B33EE166be50f482d61e1466,
            0x25DF36D0ec7D26EC791316167A5E949e65c9F8E5,
            0x350fc4F9aA8Fd42db5e8a7242E80beaeD76Db7bb,
            0x619FB742CB2B77361793DAaEBac8017642178a56,
            0xfbDdd8b5E75c22A3838E512aD535F3aE957BDd6c,
            0x9eB341621990F761cD77b4C65932625813D6e8fc,
            0xe80Af1d12426dB4394b147e04f179a38e7C5Dfe7
        ];


        address adminAddress = 0x1c1f3cd3bcBcaAF16E9566C686cfd975E49bBd64;
        address deployWallet = vm.addr(deployerPrivateKey);
        
        console.log("Admin Address:", adminAddress);
        console.log("Deployer Wallet:", deployWallet);
        
        for (uint i = 0; i < tokens.length; ++i) {
            vm.startBroadcast(deployerPrivateKey);
            console.log("Token:", tokens[i]);

            TwinToken token = TwinToken(tokens[i]);

            
            // Check current roles
            bool result = checkAdminRole(token, adminAddress);
            bool deployerResult = checkAdminRole(token, deployWallet);

            console.log("Admin role check result:", result);
            console.log("Deployer role check result:", deployerResult);
            

            // Set up roles
            //grantRoles(token, adminAddress);

            // Revoke roles
            //revokeRoles(token, deployWallet);
            
            // Renounce admin role
            //renounceAdminRole(token, deployWallet);

            vm.stopBroadcast();
        }

    }
}
