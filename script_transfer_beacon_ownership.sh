#!/bin/bash
# Usage:
#   ./script_transfer_beacon_ownership.sh               # simulation only (no tx sent)
#   ./script_transfer_beacon_ownership.sh --broadcast   # send the tx
#
# Requires in $ENV_FILE (default .env.prod):
#   RPC_URL, BEACON_ADDRESS, NEW_OWNER, OWNER_PRIVATE_KEY

ENV_FILE="${ENV_FILE:-$PWD/.env.beacon.prod}"
if [ ! -f "$ENV_FILE" ]; then
  echo "No se encontró $ENV_FILE" >&2
  exit 1
fi

set -a             # hace que cada variable cargada se exporte
source "$ENV_FILE"
set +a

for var in RPC_URL BEACON_ADDRESS NEW_OWNER OWNER_PRIVATE_KEY; do
  if [ -z "${!var}" ]; then
    echo "Falta la variable $var en $ENV_FILE" >&2
    exit 1
  fi
done

forge script \
    script/TransferBeaconOwnership.s.sol:TransferBeaconOwnershipScript \
    --rpc-url "$RPC_URL" \
    -vvvv \
    "$@"
