#!/bin/bash
set -euo pipefail

echo "[INFO] Pi bootstrap starting..."

# Wait for network
until ping -c1 github.com &>/dev/null; do
  echo "Waiting for network..."
  sleep 5
done

# Temporary directory for ephemeral certs
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

DEVICE_KEY="$TMP_DIR/device.key"
DEVICE_CSR="$TMP_DIR/device.csr"
DEVICE_CERT="$TMP_DIR/device.crt"

# Generate ephemeral device key & CSR
openssl genrsa -out "$DEVICE_KEY" 2048
openssl req -new -key "$DEVICE_KEY" -out "$DEVICE_CSR" -subj "/CN=raspberrypi-$(hostname)"

# Sign CSR using local CA (or via AWS KMS if desired)
CA_CERT="/home/pi/ca/my-root-ca.crt"
CA_KEY="/home/pi/ca/my-root-ca.key"  # Only if available in lab; in prod use KMS
openssl x509 -req -in "$DEVICE_CSR" -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial -out "$DEVICE_CERT" -days 1 -sha256

# Example: Use ephemeral cert to request AWS short-lived credentials
# aws rolesanywhere create-credential --certificate "$DEVICE_CERT" --private-key "$DEVICE_KEY"

# Example: Pull infra repo with short-lived GitHub token
# TOKEN=$(aws kms sign ... ) or pre-generated ephemeral token
# git clone https://$TOKEN@github.com/yourorg/infra-bootstrap.git /home/pi/infra-bootstrap || \
# git -C /home/pi/infra-bootstrap pull

echo "[INFO] Pi bootstrap complete — ephemeral certificate used and deleted."