#!/bin/bash
# Muestra las direcciones CREATE2 esperadas en cada red, sin enviar transacciones.
# Uso: ./predict_twin_token_create2.sh [rpc_url ...]   (sin args usa RPC_URLS del env)

set -euo pipefail

ENV_FILE="${ENV_FILE:-$PWD/.env.assets.prod}"
if [ ! -f "$ENV_FILE" ]; then
  echo "No se encontró $ENV_FILE" >&2
  exit 1
fi

set -a             # hace que cada variable cargada se exporte
source "$ENV_FILE"
set +a

export FOUNDRY_PROFILE=create2

if [ $# -gt 0 ]; then
  RPCS=("$@")
else
  IFS=',' read -ra RPCS <<< "${RPC_URLS:?Definí RPC_URLS (separadas por coma) o pasá RPCs como argumento}"
fi

for rpc in "${RPCS[@]}"; do
  echo "=============================================="
  if ! output=$(forge script \
      script/TwinTokenCreate2.d.sol:TwinTokenCreate2Deploy \
      --sig "predict()" \
      --rpc-url "$rpc" \
      -vv 2>&1); then
    echo "$output" >&2
    exit 1
  fi
  echo "$output" | sed -n '/== Logs ==/,$p'
done
