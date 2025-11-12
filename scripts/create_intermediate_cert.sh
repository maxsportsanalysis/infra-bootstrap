#!/bin/bash
set -euo pipefail
umask 077

# Parameters
INTERMEDIATE_NAME="${1:-server_tls}"  # e.g. ssl, code_signing, client_auth
OPENSSL_BIN="/home/mcilek/tmp/openssl-3.5.2/bin/openssl"
OQS_PROVIDER_PATH="/home/mcilek/tmp/openssl-3.5.2/lib64/ossl-modules"
BASE_DIR="/media/mcilek/INTERMEDIATE_CA"
ROOT_CA_DIR="/media/mcilek/ROOT_CA"

INTERMEDIATE_DIR="$BASE_DIR/$INTERMEDIATE_NAME"

mkdir -p "$INTERMEDIATE_DIR"/{certs,crl,newcerts,private,csr}
chmod 700 "$INTERMEDIATE_DIR/private"
touch "$INTERMEDIATE_DIR/index.txt"
echo 1000 > "$INTERMEDIATE_DIR/serial"
echo 1000 > "$INTERMEDIATE_DIR/crlnumber"
chmod 600 "$INTERMEDIATE_DIR/index.txt" "$INTERMEDIATE_DIR/serial" "$INTERMEDIATE_DIR/crlnumber"

INTERMEDIATE_CNF="$INTERMEDIATE_DIR/${INTERMEDIATE_NAME}.cnf"

cat > "$INTERMEDIATE_CNF" <<EOF
[ ca ]
default_ca = intermediate_ca

[ intermediate_ca ]
dir               = $INTERMEDIATE_DIR
certs             = \$dir/certs
crl_dir           = \$dir/crl
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl.pem
private_key       = \$dir/private/${INTERMEDIATE_NAME}.key.pem
certificate       = \$dir/certs/${INTERMEDIATE_NAME}.cert.pem
default_md        = sha512
policy            = policy_strict
name_opt          = ca_default
cert_opt          = ca_default
default_days      = 1825
preserve          = no
email_in_dn       = no
copy_extensions   = copy
unique_subject    = yes

[ policy_strict ]
countryName             = match
stateOrProvinceName     = match
localityName            = optional
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits       = 4096
distinguished_name = req_distinguished_name
string_mask        = utf8only
default_md         = sha512
prompt             = no
encrypt_key        = yes

[ req_distinguished_name ]
C  = US
ST = Illinois
L  = Chicago
O  = Max Sports Analysis
OU = Intermediate CA - ${INTERMEDIATE_NAME}
CN = Max Sports Analysis Intermediate CA - ${INTERMEDIATE_NAME}
emailAddress = maxsportsanalysis@gmail.com

[ v3_intermediate_ca ]
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

log() {
  echo "[`date --iso-8601=seconds`] $*"
}

log "Generating Intermediate CA private key for $INTERMEDIATE_NAME..."
if [ ! -f "$INTERMEDIATE_DIR/private/${INTERMEDIATE_NAME}.key.pem" ]; then
  $OPENSSL_BIN genpkey \
    -algorithm p384_mldsa65 \
    -provider oqsprovider \
    -provider-path "$OQS_PROVIDER_PATH" \
    -out "$INTERMEDIATE_DIR/private/${INTERMEDIATE_NAME}.key.pem"
  chmod 600 "$INTERMEDIATE_DIR/private/${INTERMEDIATE_NAME}.key.pem"
else
  log "Intermediate private key for $INTERMEDIATE_NAME already exists, skipping."
fi

log "Generating Intermediate CA CSR for $INTERMEDIATE_NAME..."
$OPENSSL_BIN req -new -key "$INTERMEDIATE_DIR/private/${INTERMEDIATE_NAME}.key.pem" \
  -out "$INTERMEDIATE_DIR/csr/${INTERMEDIATE_NAME}.csr.pem" \
  -config "$INTERMEDIATE_CNF"

log "Intermediate CSR generated at $INTERMEDIATE_DIR/csr/${INTERMEDIATE_NAME}.csr.pem"

# Signing step with Root CA (air-gapped)
if [ -d "$ROOT_CA_DIR" ] && [ -f "$ROOT_CA_DIR/root_ca.key" ]; then
  log "Signing Intermediate CSR for $INTERMEDIATE_NAME with Root CA (offline signing)..."
  touch "$ROOT_CA_DIR/index.txt"
  touch "$ROOT_CA_DIR/serial"
  chmod 600 "$ROOT_CA_DIR/index.txt" "$ROOT_CA_DIR/serial"

  $OPENSSL_BIN ca -batch -config "$ROOT_CA_DIR/root_ca.cnf" \
    -extensions root_ca_ext \
    -days 3650 \
    -notext -md sha512 \
    -in "$INTERMEDIATE_DIR/csr/${INTERMEDIATE_NAME}.csr.pem" \
    -out "$INTERMEDIATE_DIR/certs/${INTERMEDIATE_NAME}.cert.pem" \
    -keyfile "$ROOT_CA_DIR/root_ca.key" \
    -cert "$ROOT_CA_DIR/root_ca.crt" \
    -provider oqsprovider \
    -provider-path "$OQS_PROVIDER_PATH"

  chmod 644 "$INTERMEDIATE_DIR/certs/${INTERMEDIATE_NAME}.cert.pem"
  log "Intermediate CA certificate for $INTERMEDIATE_NAME generated at $INTERMEDIATE_DIR/certs/${INTERMEDIATE_NAME}.cert.pem"
else
  log "Root CA not available at $ROOT_CA_DIR, skipping signing step."
  log "Please copy intermediate CSR to Root CA USB and sign it manually."
fi

log "Intermediate CA setup complete for $INTERMEDIATE_NAME."
echo "Remember to protect your Intermediate CA key and certificate securely!"
