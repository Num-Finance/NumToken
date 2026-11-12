#!/bin/bash
# Verifica en el explorador los contratos deployados con deploy_twin_token_create2.sh.
# Uso: ./verify-twin-token-create2.sh <chainid> <factory> <impl> <beacon> <deployer> [<proxy> <name> <symbol>]
# Requiere ETHERSCAN_API_KEY (se carga de ENV_FILE, default .env.prod).

set -euo pipefail

ENV_FILE="${ENV_FILE:-$PWD/.env.assets.prod}"
if [ -f "$ENV_FILE" ]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

export FOUNDRY_PROFILE=create2

chainid=$1
factory=$2
impl=$3
beacon=$4
deployer=$5
proxy=${6:-}
name=${7:-}
symbol=${8:-}

forge verify-contract \
    --chain-id "$chainid" \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" "$deployer") \
    "$factory" \
    src/create2/TwinTokenCreate2Factory.sol:TwinTokenCreate2Factory

forge verify-contract \
    --chain-id "$chainid" \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" "0x0000000000000000000000000000000000000000") \
    "$impl" \
    src/TwinToken.sol:TwinToken

forge verify-contract \
    --chain-id "$chainid" \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" "$impl") \
    "$beacon" \
    lib/openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol:UpgradeableBeacon

if [ -n "$proxy" ]; then
  forge verify-contract \
      --chain-id "$chainid" \
      --watch \
      --constructor-args $(cast abi-encode "constructor(address,bytes)" \
          "$beacon" \
          "$(cast calldata "initialize(string,string)" "$name" "$symbol")" \
      ) \
      "$proxy" \
      lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol:BeaconProxy
fi
