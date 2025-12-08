#!/bin/bash

ENV_FILE="/home/ariel/Desktop/Num/repos/NumToken/.env.prod"
if [ ! -f "$ENV_FILE" ]; then
  echo "No se encontró $ENV_FILE" >&2
  exit 1
fi

set -a             # hace que cada variable cargada se exporte
source "$ENV_FILE"
set +a

forge script \
    script/TwinToken.d.sol:TwinTokenDeploy \
    --rpc-url $RPC_URL \
    -vvvv \
    --broadcast