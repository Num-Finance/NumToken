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

