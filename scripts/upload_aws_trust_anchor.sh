#!/bin/bash

# Usage: ./upload_trust_anchor.sh <trust-anchor-name> <path-to-intermediate-ca-pem>

set -xe

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <trust-anchor-name> <intermediate-ca-pem-file>"
  exit 1
fi

TRUST_ANCHOR_NAME="$1"
INTERMEDIATE_CA_PEM="$2"

if [ ! -f "$INTERMEDIATE_CA_PEM" ]; then
  echo "Error: File '$INTERMEDIATE_CA_PEM' does not exist."
  exit 1
fi

# PEM verification function
verify_pem() {
  local file="$1"
  
  # Check non-empty
  if [ ! -s "$file" ]; then
    echo "Error: PEM file '$file' is empty."
    return 1
  fi

  # Check for BEGIN CERTIFICATE line
  if ! head -n 1 "$file" | grep -q -- "-----BEGIN CERTIFICATE-----"; then
    echo "Error: PEM file '$file' does not start with -----BEGIN CERTIFICATE-----"
    return 1
  fi

  # Check for END CERTIFICATE line
  if ! tail -n 1 "$file" | grep -q -- "-----END CERTIFICATE-----"; then
    echo "Error: PEM file '$file' does not end with -----END CERTIFICATE-----"
    return 1
  fi
  
  return 0
}

# Verify PEM file
verify_pem "$INTERMEDIATE_CA_PEM"

echo "PEM file verification passed."

# Base64 encode the PEM file contents without line breaks
CERT_BASE64=$(base64 -w 0 < "$INTERMEDIATE_CA_PEM")

# Create the JSON payload for the AWS CLI
TMP_JSON_FILE=$(mktemp)
cat > "$TMP_JSON_FILE" <<EOF
{
  "sourceType": "CERTIFICATE_BUNDLE",
  "sourceData": {
    "x509CertificateData": "$CERT_BASE64"
  }
}
EOF

# Call AWS CLI with file input
aws rolesanywhere create-trust-anchor \
  --region us-east-2 \
  --name "$TRUST_ANCHOR_NAME" \
  --source "file://$TMP_JSON_FILE" \
  --debug

rm -f "$TMP_JSON_FILE"

echo "Trust anchor '$TRUST_ANCHOR_NAME' created successfully."
