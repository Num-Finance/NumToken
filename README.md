# NumToken

Foundry contracts and scripts used to deploy `NumToken`, `TwinToken`, price providers, and the surrounding Num tooling.

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation); install via `foundryup`.
- Optional local network with `anvil` (bundled with Foundry).
- Environment variables exported before running scripts (see samples below).

## Quick setup

```bash
foundryup            # install/update Foundry
forge install        # fetch dependencies from foundry.toml
```

## Run a local node

```bash
anvil --chain-id 31337
```

`--chain-id` can be omitted, but pinning it helps when scripts assume a specific ID. Keep the terminal running while you execute scripts or tests.

## Core Forge commands

- **Unit tests**

  ```bash
  forge test
  ```

- **Build contracts**

  ```bash
  forge build
  ```

- **Dry-run deployment (no broadcast)**

  ```bash
  forge script script/NumToken.d.sol:NumTokenDeploy \
    --rpc-url http://127.0.0.1:8545 \
    --sig "run()" \
    --fork-url http://127.0.0.1:8545
  ```

- **Actual broadcast to a local or remote RPC**

  ```bash
  DEPLOYER_PRIVATE_KEY=0xabc... \
  FORWARDER_ADDRESS=0xforwarder... \
  MINTER_BURNER_ROLE=0xaddr1,0xaddr2 \
  DISALLOW_ROLE=0xaddr3 \
  CIRCUIT_BREAKER_ROLE=0xaddr4 \
  forge script script/NumToken.d.sol:NumTokenDeploy \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast \
    --slow
  ```

- **TwinToken deployment**

  ```bash
  DEPLOYER_PRIVATE_KEY=0xabc... \
  FORWARDER_ADDRESS=0xforwarder... \
  TOKEN_NAME="Num ARS" \
  TOKEN_SYMBOL="nARS" \
  MINTER_BURNER_ROLE=0xaddr1 \
  DISALLOW_ROLE=0xaddr2 \
  CIRCUIT_BREAKER_ROLE=0xaddr3 \
  forge script script/TwinToken.d.sol:TwinTokenDeploy \
    --rpc-url http://127.0.0.1:8545 \
    --broadcast
  ```

Replace the placeholder addresses with your own and export any additional env vars required by the scripts (e.g., `DEFAULT_ADMIN_ROLE`). When targeting public networks, switch `--rpc-url` to the desired endpoint.

## Loading env vars from `.env`

If you already store all secrets/addresses in `.env`, you can export everything and run the script in one shot:

```bash
set -a && source .env && set +a && \
forge script script/TwinToken.d.sol:TwinTokenDeploy \
  --rpc-url "$RPC_URL" \
  --broadcast
```

`set -a` marks every upcoming variable for export; `set +a` restores the default after sourcing. Swap the script/flags for any other deployment you need.

## Quick verification

After every deployment you can run:

```bash
forge test --match-contract <ContractName>
```

or execute the scripts in simulation mode (`--fork-url`) to ensure the call sequence completes without reverting before sending real transactions.

# Deploy Twin Token
Set the environment variables in `.env.prod` file and run the bash script:
```bash
./deploy_twin_token.sh
```

This script will deploy the Twin Token contract and the Twin Proxy Token contract.

# Deploy Twin Proxy Token
If you want to deploy the Twin Proxy Token contract, you need to have the Twin Token contract deployed first.

This script will deploy the Twin Proxy Token contract with ths same Beacon and Implementation contracts from the Twin Token contract deployed.

Set the environment variables in `.env.prod` file and run the bash script:

```bash
./deploy_twin_proxy_token.sh
```

# Verify Twin Token
To verify the Twin Token contract, you need to have the Twin Token contract deployed first.

NOTE: For the Twin Token Proxies contracts with the same Beacon and Implementation you do not need to verify them again.

```bash
ETHERSCAN_API_KEY=your_api_key... \
./verify-twin-token.sh \
<chainid> <implementation> <forwarder> <beacon> <proxy>
```

Example:
```bash
ETHERSCAN_API_KEY=your_api_key... \
./verify-twin-token.sh 31337 0ximplemetation 0xforwarder 0xbeacon 0xproxy_contract
```

# Deploy Twin Tokens with CREATE2 (same address on every chain)

`script/TwinTokenCreate2.d.sol` deploys the factory (`src/create2/TwinTokenCreate2Factory.sol`), the `TwinToken` implementation, the beacon and every token through the deterministic CREATE2 deployer (`0x4e59b44847b379578588920cA78FbF26c0B4956C`), so all of them get the same address on every chain.

Addresses depend only on:
- the deployer wallet (`DEPLOYER_PRIVATE_KEY`)
- `CREATE2_SALT`
- `TOKEN_NAMES` and `TOKEN_SYMBOLS`
- the compiled bytecode: always use `FOUNDRY_PROFILE=create2` (the scripts set it) and deploy every chain from the same commit

`DEFAULT_ADMIN_ROLE` and the role lists can differ per chain without changing addresses. The ERC2771 forwarder is hardcoded to `address(0)` (no gasless transactions).

## Environment

Add the variables to `.env.prod` (see `.env.example`). Lists with spaces must be quoted:

```bash
DEPLOYER_PRIVATE_KEY=0xabc...
CREATE2_SALT=twin.v1
TOKEN_NAMES="Argentine Peso token,Brazilian Real token"
TOKEN_SYMBOLS="ARGt,BRAt"
DEFAULT_ADMIN_ROLE=0xmultisig...
MINTER_BURNER_ROLE=0xaddr1,0xaddr2
DISALLOW_ROLE=0xaddr3
CIRCUIT_BREAKER_ROLE=0xaddr4
RPC_URLS="https://arb-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY,https://base-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY"
ETHERSCAN_API_KEY=your_api_key...
```

Use another env file with `ENV_FILE=path/to/file`.

## Predict

Prints the expected addresses on each chain and whether they are already deployed. No transactions are sent. Check that the addresses match on every chain before deploying.

```bash
./predict_twin_token_create2.sh                                   # every RPC in RPC_URLS
./predict_twin_token_create2.sh https://polygon-rpc.com           # a single chain
```

Example output (local anvil with the default test key; your addresses will differ):

```
Chain id: 42161
Deployer: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
CREATE2 deployer present: true
Factory:        0x8680520DB781D092203758ac088C1d5399C0B7e4 pending
Implementation: 0x83bFBA61B169C70FF3aeD7243ED70db04836B615 pending
Beacon:         0x2BaB215BF03ce664976Fd4b431e5e40C2768b2E6 pending
ARGt: 0xAFb34a72c407aff9aF41c8Fc1DAeE8A2eA3853a6 pending
BRAt: 0xe10313c271fDe84442683f5f63bEEEA15621fa99 pending
```

## Deploy

Commit your changes first: the script refuses to run with uncommitted changes in `src`, `script`, `foundry.toml` or `lib` (override with `ALLOW_DIRTY=1`, only for local tests). For each chain it shows the prediction and asks for confirmation.

```bash
./deploy_twin_token_create2.sh                                    # every RPC in RPC_URLS
./deploy_twin_token_create2.sh https://polygon-rpc.com            # a single chain
VERIFY=1 ./deploy_twin_token_create2.sh                           # deploy and verify on the explorer
YES=1 ./deploy_twin_token_create2.sh                              # skip the confirmation prompt
```

The deployment is idempotent: anything already deployed is skipped. To add tokens to the series, append them to `TOKEN_NAMES`/`TOKEN_SYMBOLS` and run it again.

Test it locally first:

```bash
anvil --chain-id 31337
ALLOW_DIRTY=1 ./deploy_twin_token_create2.sh http://127.0.0.1:8545
```

## Verify

If you did not deploy with `VERIFY=1`, verify manually with the addresses printed by `predict`. The token arguments are optional: the factory, implementation and beacon are verified once per chain, then each proxy.

```bash
./verify-twin-token-create2.sh \
<chainid> <factory> <implementation> <beacon> <deployer> [<proxy> <token_name> <token_symbol>]
```

Example (addresses from the anvil output above):
```bash
./verify-twin-token-create2.sh 42161 \
  0x8680520DB781D092203758ac088C1d5399C0B7e4 \
  0x83bFBA61B169C70FF3aeD7243ED70db04836B615 \
  0x2BaB215BF03ce664976Fd4b431e5e40C2768b2E6 \
  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  0xAFb34a72c407aff9aF41c8Fc1DAeE8A2eA3853a6 "Argentine Peso token" "ARGt"
```

To verify only another proxy, run the same command: already verified contracts are reported as such.

## Tests

```bash
FOUNDRY_PROFILE=create2 forge test --match-contract TwinTokenCreate2
```
