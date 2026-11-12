pragma solidity ^0.8.15;

import "forge-std/Script.sol";
import "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

import "src/TwinToken.sol";
import "src/create2/TwinTokenCreate2Factory.sol";

/**
 * @title TwinTokenCreate2Deploy
 * @author Twin Finance
 * @notice Deploys TwinTokens with CREATE2 so factory, implementation, beacon and every token
 *         get the same address on every chain.
 *
 * Addresses depend only on: the deployer EOA (factory owner), CREATE2_SALT, TOKEN_NAMES, TOKEN_SYMBOLS
 * and the compiled bytecode (use FOUNDRY_PROFILE=create2 and the same commit on every chain).
 * Roles, admin and beacon owner can differ per chain without changing addresses.
 *
 * - predict(): prints the expected addresses, no transactions.
 * - run():     deploys whatever is missing (idempotent).
 */
contract TwinTokenCreate2Deploy is Script {
    /// @dev ERC2771 forwarder. Hardcoded to address(0) (no gasless transactions) because it is part of
    ///      the implementation's init code: a different value on any chain would change every address.
    address internal constant FORWARDER = address(0);

    struct Deployment {
        address factory;
        address implementation;
        address beacon;
    }

    function _salt(string memory label) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(vm.envString("CREATE2_SALT"), ":", label)
            );
    }

    function _tokens()
        internal
        view
        returns (string[] memory names, string[] memory symbols)
    {
        names = vm.envString("TOKEN_NAMES", ",");
        symbols = vm.envString("TOKEN_SYMBOLS", ",");
        require(
            names.length == symbols.length,
            "TOKEN_NAMES and TOKEN_SYMBOLS length mismatch"
        );
    }

    function _deployment(
        address deployer
    ) internal view returns (Deployment memory d) {
        d.factory = vm.computeCreate2Address(
            _salt("factory"),
            keccak256(
                abi.encodePacked(
                    type(TwinTokenCreate2Factory).creationCode,
                    abi.encode(deployer)
                )
            )
        );
        d.implementation = vm.computeCreate2Address(
            _salt("implementation"),
            keccak256(
                abi.encodePacked(
                    type(TwinToken).creationCode,
                    abi.encode(FORWARDER)
                )
            )
        );
        d.beacon = vm.computeCreate2Address(
            _salt("beacon"),
            keccak256(
                abi.encodePacked(
                    type(UpgradeableBeacon).creationCode,
                    abi.encode(d.implementation)
                )
            ),
            d.factory
        );
    }

    function _tokenAddress(
        Deployment memory d,
        string memory name,
        string memory symbol
    ) internal view returns (address) {
        bytes memory initCode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(
                d.beacon,
                abi.encodeCall(TwinToken.initialize, (name, symbol))
            )
        );
        return
            vm.computeCreate2Address(
                _salt(symbol),
                keccak256(initCode),
                d.factory
            );
    }

    function _status(address account) internal view returns (string memory) {
        return account.code.length > 0 ? "deployed" : "pending";
    }

    /**
     * @notice Prints the expected addresses on the current chain without sending transactions.
     */
    function predict() external view {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        Deployment memory d = _deployment(deployer);
        (string[] memory names, string[] memory symbols) = _tokens();

        console.log(
            string(abi.encodePacked("Chain id: ", vm.toString(block.chainid)))
        );
        console.log("Deployer:", deployer);
        console.log(
            "CREATE2 deployer present:",
            CREATE2_FACTORY.code.length > 0
        );
        console.log(
            string(
                abi.encodePacked(
                    "Factory:        ",
                    vm.toString(d.factory),
                    " ",
                    _status(d.factory)
                )
            )
        );
        console.log(
            string(
                abi.encodePacked(
                    "Implementation: ",
                    vm.toString(d.implementation),
                    " ",
                    _status(d.implementation)
                )
            )
        );
        console.log(
            string(
                abi.encodePacked(
                    "Beacon:         ",
                    vm.toString(d.beacon),
                    " ",
                    _status(d.beacon)
                )
            )
        );

        for (uint i = 0; i < symbols.length; ++i) {
            address token = _tokenAddress(d, names[i], symbols[i]);
            console.log(
                string(
                    abi.encodePacked(
                        symbols[i],
                        ": ",
                        vm.toString(token),
                        " ",
                        _status(token)
                    )
                )
            );
        }
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address admin = vm.envAddress("DEFAULT_ADMIN_ROLE");
        address beaconOwner = vm.envAddress("DEFAULT_ADMIN_ROLE");
        (string[] memory names, string[] memory symbols) = _tokens();

        TwinTokenCreate2Factory.Roles memory roles;
        roles.minters = vm.envOr("MINTER_BURNER_ROLE", ",", new address[](0));
        roles.disallowers = vm.envOr("DISALLOW_ROLE", ",", new address[](0));
        roles.breakers = vm.envOr(
            "CIRCUIT_BREAKER_ROLE",
            ",",
            new address[](0)
        );

        require(
            CREATE2_FACTORY.code.length > 0,
            "CREATE2 deployer not present on this chain"
        );

        Deployment memory d = _deployment(deployer);
        TwinTokenCreate2Factory factory = TwinTokenCreate2Factory(d.factory);

        console.log(
            string(abi.encodePacked("Chain id: ", vm.toString(block.chainid)))
        );
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        if (d.factory.code.length == 0) {
            address deployed = address(
                new TwinTokenCreate2Factory{salt: _salt("factory")}(deployer)
            );
            require(deployed == d.factory, "Factory address mismatch");
        }
        console.log("Factory:", d.factory);

        if (d.implementation.code.length == 0) {
            address deployed = address(
                new TwinToken{salt: _salt("implementation")}(FORWARDER)
            );
            require(
                deployed == d.implementation,
                "Implementation address mismatch"
            );
        }
        console.log("Implementation:", d.implementation);

        if (d.beacon.code.length == 0) {
            address deployed = factory.deployBeacon(
                _salt("beacon"),
                d.implementation,
                beaconOwner
            );
            require(deployed == d.beacon, "Beacon address mismatch");
        }
        console.log("Beacon:", d.beacon);

        for (uint i = 0; i < symbols.length; ++i) {
            address expected = _tokenAddress(d, names[i], symbols[i]);

            if (expected.code.length > 0) {
                console.log(
                    string(
                        abi.encodePacked(
                            symbols[i],
                            " already deployed at ",
                            vm.toString(expected)
                        )
                    )
                );
                continue;
            }

            address token = factory.deployToken(
                _salt(symbols[i]),
                d.beacon,
                names[i],
                symbols[i],
                admin,
                roles
            );
            require(token == expected, "Token address mismatch");

            console.log(
                string(
                    abi.encodePacked(
                        names[i],
                        " deployed to ",
                        vm.toString(token)
                    )
                )
            );
        }

        vm.stopBroadcast();

        _check(d, names, symbols, admin);
    }

    /**
     * @dev Post-deployment sanity checks.
     */
    function _check(
        Deployment memory d,
        string[] memory names,
        string[] memory symbols,
        address admin
    ) internal view {
        UpgradeableBeacon beacon = UpgradeableBeacon(d.beacon);
        console.log("Beacon owner:", beacon.owner());
        if (beacon.implementation() != d.implementation)
            console.log(
                "WARNING: beacon points to a different implementation:",
                beacon.implementation()
            );

        for (uint i = 0; i < symbols.length; ++i) {
            TwinToken token = TwinToken(_tokenAddress(d, names[i], symbols[i]));
            require(
                keccak256(bytes(token.symbol())) ==
                    keccak256(bytes(symbols[i])),
                "Unexpected symbol"
            );
            require(
                !token.hasRole(token.DEFAULT_ADMIN_ROLE(), d.factory),
                "Factory still has admin role"
            );
            if (!token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin))
                console.log(
                    string(
                        abi.encodePacked(
                            "WARNING: ",
                            symbols[i],
                            " admin is not DEFAULT_ADMIN_ROLE from env"
                        )
                    )
                );
        }
    }
}
