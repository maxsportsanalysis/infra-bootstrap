#!/bin/bash
set -euo pipefail
umask 077

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <intermediate_ca_dir> <certificate_to_revoke.pem>"
  exit 1
fi

INTERMEDIATE_DIR="$1"
CERT_TO_REVOKE="$2"

OPENSSL_BIN="/home/mcilek/tmp/openssl-3.5.2/bin/openssl"
OQS_PROVIDER_PATH="/home/mcilek/tmp/openssl-3.5.2/lib64/ossl-modules"

CONFIG_FILE="$INTERMEDIATE_DIR/$(basename "$INTERMEDIATE_DIR").cnf"

if [ ! -f "$CERT_TO_REVOKE" ]; then
  echo "Error: Certificate file to revoke does not exist: $CERT_TO_REVOKE"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Intermediate CA config not found at $CONFIG_FILE"
  exit 1
fi

echo "Revoking certificate: $CERT_TO_REVOKE"
sudo $OPENSSL_BIN ca \
  -config "$CONFIG_FILE" \
  -revoke "$CERT_TO_REVOKE" \
  -provider oqsprovider \
  -provider-path "$OQS_PROVIDER_PATH"

echo "Certificate revoked. Remember to generate a new CRL!"
