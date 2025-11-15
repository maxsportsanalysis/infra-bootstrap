#!/bin/bash
set -euo pipefail
umask 077

OPENSSL_BIN="/home/mcilek/tmp/openssl-3.5.2/bin/openssl"
OQS_PROVIDER_PATH="/home/mcilek/tmp/openssl-3.5.2/lib64/ossl-modules"
OUTPUT_DIR="/media/mcilek/ROOT_CA"
CONFIG_FILE="${OUTPUT_DIR}/root_ca.cnf"

log() {
  echo "[`date --iso-8601=seconds`] $*"
}

log "Creating output directory at $OUTPUT_DIR..."
mkdir -p "$OUTPUT_DIR/newcerts"
chmod 700 "$OUTPUT_DIR"
touch "$OUTPUT_DIR/index.txt"
echo 1000 > "$OUTPUT_DIR/serial"
echo 1000 > "$OUTPUT_DIR/crlnumber"
chmod 600 "$OUTPUT_DIR/index.txt" "$OUTPUT_DIR/serial" "$OUTPUT_DIR/crlnumber"

command -v openssl >/dev/null 2>&1 || { echo "Error: openssl not found."; exit 1; }

if [ ! -f "${OUTPUT_DIR}/root_ca.key" ]; then
  log "Generating RSA 4096-bit Root CA private key..."
  $OPENSSL_BIN genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:4096 \
    -out "${OUTPUT_DIR}/root_ca.key"
  chmod 600 "${OUTPUT_DIR}/root_ca.key"
else
  log "Root CA private key already exists, skipping generation."
fi

# === Write OpenSSL root CA config ===
log "Writing OpenSSL configuration file..."
cat > "$CONFIG_FILE" <<EOF
# Root CA config for Max Sports Analysis
# Hybrid PQC (mldsa) root CA, SHA-512 hashing, production-ready

[ default ]
ca                      = maxsportsanalysis_root_ca
dir                     = $OUTPUT_DIR

[ req ]
default_bits            = 4096
encrypt_key             = yes
default_md              = sha512
utf8                    = yes
string_mask             = utf8only
prompt                  = no
distinguished_name      = ca_dn
req_extensions          = root_ca_ext

[ ca_dn ]
C                       = US
ST                      = Illinois
L                       = Chicago
O                       = Max Sports Analysis
OU                      = Root CA
CN                      = Max Sports Analysis Root CA
emailAddress            = maxsportsanalysis@gmail.com

[ root_ca_ext ]
basicConstraints        = critical,CA:true
keyUsage                = critical,keyCertSign,cRLSign
subjectKeyIdentifier    = hash
authorityKeyIdentifier  = keyid:always,issuer

[ ca ]
default_ca              = maxsportsanalysis_root_ca

[ maxsportsanalysis_root_ca ]
certificate             = \$dir/root_ca.crt
private_key             = \$dir/root_ca.key
new_certs_dir           = \$dir/newcerts
database                = \$dir/index.txt
serial                  = \$dir/serial
crlnumber               = \$dir/crlnumber
crl                     = \$dir/root_ca.crl.pem
default_days            = 3652
default_md              = sha512
preserve                = no
policy                  = maxsportsanalysis_policy
email_in_dn             = no
unique_subject          = no
copy_extensions         = none
x509_extensions         = root_ca_ext
default_crl_days        = 365
crl_extensions          = crl_ext

[ maxsportsanalysis_policy ]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ crl_ext ]
authorityKeyIdentifier  = keyid:always
EOF
chmod 600 "$CONFIG_FILE"

if [ ! -f "${OUTPUT_DIR}/root_ca.crt" ]; then
  log "Generating self-signed Root CA certificate..."
  $OPENSSL_BIN req -x509 -new -key "${OUTPUT_DIR}/root_ca.key" \
    -out "${OUTPUT_DIR}/root_ca.crt" -days 3650 \
    -config "$CONFIG_FILE" -extensions root_ca_ext \
    -sha512
  chmod 644 "${OUTPUT_DIR}/root_ca.crt"
else
  log "Root CA certificate already exists, skipping generation."
fi

log "Root CA generation complete."
log "Files:"
log "  Private Key: ${OUTPUT_DIR}/root_ca.key"
log "  Certificate: ${OUTPUT_DIR}/root_ca.crt"
log "  Config File: ${CONFIG_FILE}"
