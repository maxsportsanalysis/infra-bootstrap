#!/bin/bash
set -euo pipefail
umask 077

###############################################################################
# Configuration
###############################################################################
INTERMEDIATE_NAME="${1:-server_tls}"  # Example: server_tls, client_auth, code_signing
OPENSSL_BIN="/home/mcilek/tmp/openssl-3.5.2/bin/openssl"
OQS_PROVIDER_PATH="/home/mcilek/tmp/openssl-3.5.2/lib64/ossl-modules"
BASE_DIR="/media/mcilek/INTERMEDIATE_CA"
ROOT_CA_DIR="/media/mcilek/ROOT_CA"

INTERMEDIATE_DIR="$BASE_DIR/$INTERMEDIATE_NAME"
INTERMEDIATE_CNF="$INTERMEDIATE_DIR/${INTERMEDIATE_NAME}.cnf"

###############################################################################
# Helper Logging
###############################################################################
log() {
    printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

###############################################################################
# Directory Setup
###############################################################################
log "Setting up intermediate CA directory structure at $INTERMEDIATE_DIR..."

mkdir -p "$INTERMEDIATE_DIR"

for subdir in certs crl newcerts private csr; do
    mkdir -p "$INTERMEDIATE_DIR/$subdir"
done

chmod 700 "$INTERMEDIATE_DIR/private"

# PKI database files
: > "$INTERMEDIATE_DIR/index.txt"
echo 1000 > "$INTERMEDIATE_DIR/serial"
echo 1000 > "$INTERMEDIATE_DIR/crlnumber"

chmod 600 "$INTERMEDIATE_DIR/index.txt" "$INTERMEDIATE_DIR/serial" "$INTERMEDIATE_DIR/crlnumber"

###############################################################################
# Generate Intermediate CA OpenSSL Config
###############################################################################
log "Generating OpenSSL config at $INTERMEDIATE_CNF..."

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
default_md        = sha256
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
default_bits       = 3072
distinguished_name = req_distinguished_name
string_mask        = utf8only
default_md         = sha256
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

###############################################################################
# Key Generation (only if missing)
#p384_mldsa65
###############################################################################
KEY_PATH="$INTERMEDIATE_DIR/private/${INTERMEDIATE_NAME}.key.pem"
if [[ ! -f "$KEY_PATH" ]]; then
    log "Generating intermediate private key using RSA 3072..."
    "$OPENSSL_BIN" genpkey \
        -algorithm RSA \
        -pkeyopt rsa_keygen_bits:3072 \
        -out "$KEY_PATH"
    chmod 600 "$KEY_PATH"
else
    log "Key already exists at $KEY_PATH — skipping generation."
fi


###############################################################################
# CSR Generation
###############################################################################
CSR_PATH="$INTERMEDIATE_DIR/csr/${INTERMEDIATE_NAME}.csr.pem"
log "Generating CSR at $CSR_PATH..."

"$OPENSSL_BIN" req -new \
    -key "$KEY_PATH" \
    -out "$CSR_PATH" \
    -config "$INTERMEDIATE_CNF"

###############################################################################
# Sign Using Root CA (if available)
###############################################################################
CERT_PATH="$INTERMEDIATE_DIR/certs/${INTERMEDIATE_NAME}.cert.pem"

if [[ -f "$ROOT_CA_DIR/root_ca.key" && -f "$ROOT_CA_DIR/root_ca.crt" && -f "$ROOT_CA_DIR/root_ca.cnf" ]]; then
    log "Root CA detected — performing offline signing..."

    : > "$ROOT_CA_DIR/index.txt"
    echo 1000 > "$ROOT_CA_DIR/serial"
    chmod 600 "$ROOT_CA_DIR/index.txt" "$ROOT_CA_DIR/serial"

    "$OPENSSL_BIN" ca -batch \
      -config "$ROOT_CA_DIR/root_ca.cnf" \
      -extensions root_ca_ext \
      -days 3650 \
      -notext \
      -md sha256 \
      -in "$CSR_PATH" \
      -out "$CERT_PATH" \
      -keyfile "$ROOT_CA_DIR/root_ca.key" \
      -cert "$ROOT_CA_DIR/root_ca.crt"

    chmod 644 "$CERT_PATH"
    log "Intermediate certificate created at $CERT_PATH"
else
    log "Root CA not available — skipping signing step."
    log "Copy CSR to air-gapped root CA for manual signing."
fi

log "Intermediate CA setup complete for: $INTERMEDIATE_NAME"
echo "→ Protect the intermediate key: $KEY_PATH"