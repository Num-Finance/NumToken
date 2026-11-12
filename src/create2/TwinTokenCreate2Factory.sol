pragma solidity ^0.8.15;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/proxy/beacon/BeaconProxy.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import "openzeppelin/utils/Create2.sol";

import "src/TwinToken.sol";

/**
 * @title TwinTokenCreate2Factory
 * @author Twin Finance
 * @notice Deploys TwinToken beacons and proxies with CREATE2, so they get the same address on every chain.
 *
 * The factory is meant to be deployed through the deterministic CREATE2 deployer
 * (0x4e59b44847b379578588920cA78FbF26c0B4956C) with the same owner on every chain.
 *
 * Deploying through a factory solves two problems of a plain CREATE2 deployment:
 *   - UpgradeableBeacon sets its owner to msg.sender, so ownership is transferred in the same transaction.
 *   - TwinToken::initialize grants DEFAULT_ADMIN_ROLE to msg.sender, so the factory initializes the proxy
 *     in its constructor, grants the roles and renounces its own admin role atomically (no front-running).
 *
 * Roles and beacon owner are not part of the init code, so they can differ per chain without changing addresses.
 */
contract TwinTokenCreate2Factory is Ownable {
    /// @notice Accounts that receive each operational role on a new token.
    struct Roles {
        address[] minters;
        address[] disallowers;
        address[] breakers;
    }

    /// @notice Emitted when a beacon is deployed.
    event BeaconDeployed(address indexed beacon, address indexed implementation, address indexed owner, bytes32 salt);

    /// @notice Emitted when a token proxy is deployed.
    event TokenDeployed(address indexed token, address indexed beacon, address indexed admin, bytes32 salt, string symbol);

    constructor(address owner_) {
        _transferOwnership(owner_);
    }

    /**
     * @notice Deploys an UpgradeableBeacon pointing to {implementation} and transfers its ownership to {beaconOwner}.
     * @param salt CREATE2 salt.
     * @param implementation TwinToken implementation address.
     * @param beaconOwner Account allowed to upgrade the beacon.
     */
    function deployBeacon(bytes32 salt, address implementation, address beaconOwner)
        external
        onlyOwner
        returns (address)
    {
        require(beaconOwner != address(0), "TwinTokenCreate2Factory: zero owner");

        UpgradeableBeacon beacon = new UpgradeableBeacon{salt: salt}(implementation);
        beacon.transferOwnership(beaconOwner);

        emit BeaconDeployed(address(beacon), implementation, beaconOwner, salt);
        return address(beacon);
    }

    /**
     * @notice Deploys and initializes a TwinToken BeaconProxy, grants roles and hands DEFAULT_ADMIN_ROLE to {admin}.
     * @param salt CREATE2 salt.
     * @param beacon UpgradeableBeacon address.
     * @param name_ Token name.
     * @param symbol_ Token symbol.
     * @param admin Account that receives DEFAULT_ADMIN_ROLE.
     * @param roles Accounts that receive MINTER_BURNER_ROLE, DISALLOW_ROLE and CIRCUIT_BREAKER_ROLE.
     */
    function deployToken(
        bytes32 salt,
        address beacon,
        string calldata name_,
        string calldata symbol_,
        address admin,
        Roles calldata roles
    ) external onlyOwner returns (address) {
        require(admin != address(0), "TwinTokenCreate2Factory: zero admin");

        address proxy = address(new BeaconProxy{salt: salt}(beacon, _initData(name_, symbol_)));
        _setupRoles(TwinToken(proxy), admin, roles);

        emit TokenDeployed(proxy, beacon, admin, salt, symbol_);
        return proxy;
    }

    /**
     * @dev Grants the operational roles, hands DEFAULT_ADMIN_ROLE to {admin} and renounces the factory's admin role.
     */
    function _setupRoles(TwinToken token, address admin, Roles calldata roles) internal {
        for (uint i = 0; i < roles.minters.length; ++i)
            token.grantRole(token.MINTER_BURNER_ROLE(), roles.minters[i]);
        for (uint i = 0; i < roles.disallowers.length; ++i)
            token.grantRole(token.DISALLOW_ROLE(), roles.disallowers[i]);
        for (uint i = 0; i < roles.breakers.length; ++i)
            token.grantRole(token.CIRCUIT_BREAKER_ROLE(), roles.breakers[i]);

        token.grantRole(token.DEFAULT_ADMIN_ROLE(), admin);
        token.renounceRole(token.DEFAULT_ADMIN_ROLE(), address(this));
    }

    /**
     * @notice Returns the address a beacon deployed with {salt} and {implementation} will have.
     */
    function predictBeacon(bytes32 salt, address implementation) external view returns (address) {
        bytes memory initCode = abi.encodePacked(type(UpgradeableBeacon).creationCode, abi.encode(implementation));
        return Create2.computeAddress(salt, keccak256(initCode));
    }

    /**
     * @notice Returns the address a token deployed with {salt}, {beacon}, {name_} and {symbol_} will have.
     */
    function predictToken(bytes32 salt, address beacon, string calldata name_, string calldata symbol_)
        external
        view
        returns (address)
    {
        bytes memory initCode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(beacon, _initData(name_, symbol_))
        );
        return Create2.computeAddress(salt, keccak256(initCode));
    }

    function _initData(string calldata name_, string calldata symbol_) internal pure returns (bytes memory) {
        return abi.encodeCall(TwinToken.initialize, (name_, symbol_));
    }
}
