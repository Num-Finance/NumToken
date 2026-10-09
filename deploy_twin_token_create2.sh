#!/bin/bash
# Deploya factory, implementación, beacon y TwinTokens con CREATE2 (mismas direcciones en todas las redes).
# Uso: ./deploy_twin_token_create2.sh [rpc_url ...]   (sin args usa RPC_URLS del env)
# Variables opcionales: ENV_FILE (default .env.prod), VERIFY=1, YES=1 (no pide confirmación), ALLOW_DIRTY=1,
#   AMSTERDAM_CHAIN_IDS (default 11155111): redes con Glamsterdam activo. Ahí forge tiene que estimar el gas
#   con las reglas nuevas (EIP-8037), si no las transacciones se quedan sin gas. Requiere Foundry >= 1.8.5.

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

# Mismo commit => mismo bytecode => mismas direcciones. Un cambio local en los fuentes cambia las direcciones.
if [ "${ALLOW_DIRTY:-0}" != "1" ] && [ -n "$(git status --porcelain --untracked-files=no -- src script foundry.toml remappings.txt lib)" ]; then
  echo "Hay cambios sin commitear en src/script/foundry.toml/lib. Commiteá antes de deployar (o ALLOW_DIRTY=1)." >&2
  exit 1
fi
echo "Commit: $(git rev-parse HEAD)"

if [ $# -gt 0 ]; then
  RPCS=("$@")
else
  IFS=',' read -ra RPCS <<< "${RPC_URLS:?Definí RPC_URLS (separadas por coma) o pasá RPCs como argumento}"
fi

VERIFY_ARGS=()
if [ "${VERIFY:-0}" = "1" ]; then
  VERIFY_ARGS=(--verify --verifier etherscan)
fi

for rpc in "${RPCS[@]}"; do
  chain_id=$(cast chain-id --rpc-url "$rpc")
  echo "=============================================="
  echo "Chain id: $chain_id"

  # Solo cambia las reglas de gas de la simulación, no el bytecode (evm_version de compilación sigue en paris).
  if [[ ",${AMSTERDAM_CHAIN_IDS:-11155111}," == *",$chain_id,"* ]]; then
    forge_version=$(forge --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ "$(printf '%s\n' 1.8.5 "$forge_version" | sort -V | head -1)" != "1.8.5" ]; then
      echo "Chain $chain_id tiene Glamsterdam y forge $forge_version estima mal el gas. Actualizá con foundryup (>= 1.8.5)." >&2
      exit 1
    fi
    export FOUNDRY_HARDFORK=amsterdam
    echo "Gas estimado con reglas Glamsterdam (amsterdam)"
  else
    unset FOUNDRY_HARDFORK
  fi

  if ! output=$(forge script \
      script/TwinTokenCreate2.d.sol:TwinTokenCreate2Deploy \
      --sig "predict()" \
      --rpc-url "$rpc" \
      -vv 2>&1); then
    echo "$output" >&2
    exit 1
  fi
  echo "$output" | sed -n '/== Logs ==/,$p'

  if [ "${YES:-0}" != "1" ]; then
    read -r -p "¿Deployar en chain $chain_id? [y/N] " answer
    if [ "$answer" != "y" ]; then
      echo "Salteando chain $chain_id"
      continue
    fi
  fi

  forge script \
      script/TwinTokenCreate2.d.sol:TwinTokenCreate2Deploy \
      --rpc-url "$rpc" \
      -vvv \
      --slow \
      "${VERIFY_ARGS[@]}" \
      --broadcast
done
