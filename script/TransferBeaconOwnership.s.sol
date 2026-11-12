pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @title TransferBeaconOwnershipScript
 * @author Twin Finance
 * @notice Transfers ownership of an UpgradeableBeacon to a new wallet.
 *
 * Env vars:
 *  - BEACON_ADDRESS:      address of the UpgradeableBeacon
 *  - NEW_OWNER:           address that will become the new owner
 *  - OWNER_PRIVATE_KEY:   private key of the current owner (signs the tx)
 *
 * NOTE: OpenZeppelin v4 Ownable transfer is single step. If NEW_OWNER is wrong,
 * control over beacon upgrades is lost. Double check the address and chain.
 */
contract TransferBeaconOwnershipScript is Script {
    function run() external {
        address beaconAddress = vm.envAddress("BEACON_ADDRESS");
        address newOwner = vm.envAddress("NEW_OWNER");
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        address signer = vm.addr(ownerPrivateKey);

        require(
            beaconAddress.code.length > 0,
            "BEACON_ADDRESS has no code on this chain"
        );
        require(newOwner != address(0), "NEW_OWNER is the zero address");

        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddress);
        address currentOwner = beacon.owner();

        console.log("Chain ID:        ", block.chainid);
        console.log("Beacon:          ", beaconAddress);
        console.log("Implementation:  ", beacon.implementation());
        console.log("Current owner:   ", currentOwner);
        console.log("Signer:          ", signer);
        console.log("New owner:       ", newOwner);
        console.log("New owner is contract:", newOwner.code.length > 0);

        require(
            currentOwner == signer,
            "Signer is not the current beacon owner"
        );
        require(newOwner != currentOwner, "NEW_OWNER is already the owner");

        vm.startBroadcast(ownerPrivateKey);
        beacon.transferOwnership(newOwner);
        vm.stopBroadcast();

        require(beacon.owner() == newOwner, "Ownership transfer failed");
        console.log("Ownership transferred to:", beacon.owner());
    }
}
