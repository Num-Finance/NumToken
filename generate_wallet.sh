#!/bin/bash
# Genera una wallet EVM random e imprime address, public key y private key. No guarda nada.
# Uso: ./generate_wallet.sh

set -euo pipefail

if ! command -v cast >/dev/null 2>&1; then
  echo "No se encontró cast. Instalá Foundry con foundryup." >&2
  exit 1
fi

wallet=$(cast wallet new --json)
private_key=$(echo "$wallet" | grep -oE '0x[0-9a-fA-F]{64}')

echo "Address:     $(cast wallet address --private-key "$private_key")"
echo "Public key:  $(cast wallet public-key --private-key "$private_key")"
echo "Private key: $private_key"
