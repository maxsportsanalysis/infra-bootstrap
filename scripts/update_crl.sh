#!/bin/bash
set -euo pipefail
umask 077

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <intermediate_ca_dir>"
  exit 1
fi

INTERMEDIATE_DIR="$1"

OPENSSL_BIN="/home/mcilek/tmp/openssl-3.5.2/bin/openssl"
OQS_PROVIDER_PATH="/home/mcilek/tmp/openssl-3.5.2/lib64/ossl-modules"

CONFIG_FILE="$INTERMEDIATE_DIR/$(basename "$INTERMEDIATE_DIR").cnf"
CRL_OUTPUT="$INTERMEDIATE_DIR/crl/$(basename "$INTERMEDIATE_DIR").crl.pem"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Intermediate CA config not found at $CONFIG_FILE"
  exit 1
fi

echo "Generating new CRL at $CRL_OUTPUT"
sudo $OPENSSL_BIN ca \
  -config "$CONFIG_FILE" \
  -gencrl \
  -out "$CRL_OUTPUT" \
  -provider oqsprovider \
  -provider-path "$OQS_PROVIDER_PATH"

echo "CRL updated: $CRL_OUTPUT"
