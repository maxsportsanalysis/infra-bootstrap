#!/bin/bash

openssl list -signature-algorithms -provider oqsprovider #-provider-path $OPENSSL_MODULES
openssl list -providers -provider oqsprovider

openssl list -kem-algorithms

# { 1.2.840.113549.1.1.1, 2.5.8.1.1, RSA, rsaEncryption } @ default
# { 1.2.840.10045.2.1, EC, id-ecPublicKey } @ default
# { 1.3.101.110, X25519 } @ default
# { 1.3.101.111, X448 } @ default
# { 2.16.840.1.101.3.4.4.1, id-alg-ml-kem-512, ML-KEM-512, MLKEM512 } @ default
# { 2.16.840.1.101.3.4.4.2, id-alg-ml-kem-768, ML-KEM-768, MLKEM768 } @ default
# { 2.16.840.1.101.3.4.4.3, id-alg-ml-kem-1024, ML-KEM-1024, MLKEM1024 } @ default
# X25519MLKEM768 @ default
# X448MLKEM1024 @ default
# SecP256r1MLKEM768 @ default
# SecP384r1MLKEM1024 @ default

# Generate a hybrid (RSA + Dilithium) CA certificate (requires patched OpenSSL with OQS)
/usr/local/openssl-3.5.2/bin/openssl genpkey -algorithm hybrid:rsa3072_dilithium3 -out hybrid-root-key.pem

/usr/local/openssl-3.5.2/bin/openssl req -new -x509 -key hybrid-root-key.pem \
  -subj "/CN=Hybrid Root CA" \
  -days 3650 \
  -out hybrid-root-cert.pem