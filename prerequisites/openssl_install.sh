#!/bin/bash

# 1. A "make" implementation
# 2. Perl 5 with core modules
# 3. The Perl module "Text::Template" (https://github.com/openssl/openssl/blob/master/NOTES-PERL.md): sudo apt-get install libtext-template-perl
# 4. a C-99 compiler
# 5. POSIX C library (at least POSIX.1-2008), or compatible types and functionality.
# 6. A development environment in the form of development libraries and C header files

cd /usr/local/src
sudo wget https://github.com/openssl/openssl/releases/download/openssl-3.5.2/openssl-3.5.2.tar.gz
sudo tar -xf openssl-3.5.2.tar.gz
sudo rm openssl-3.5.2.tar.gz

cd openssl-3.5.2


# Configure with a safe prefix
# --openssldir (default: /usr/local/ssl) - Directory for OpenSSL configuration files, and also the default certificate and key store.
# --prefix (default: /usr/local) - The top of the installation directory tree.
sudo ./config --prefix=/usr/local/openssl-3.5.2 \
         --openssldir=/usr/local/openssl-3.5.2 \
         shared zlib fips \
         '-Wl,-rpath,$(LIBRPATH)'
      
# Build with all CPU cores
sudo make -j$(nproc)

# Install into /usr/local/openssl-3.5.2
sudo make install

# Now the system OpenSSL (apt package) is untouched. To use your custom one: /usr/local/openssl-3.5.2/bin/openssl version -a

# If you want to temporarily prefer the custom version in your shell: export PATH=/usr/local/openssl-3.3.2/bin:$PATH
# Since you didn’t overwrite /usr/bin/openssl, the apt version is still installed. If you ever want to remove your custom build: sudo rm -rf /usr/local/openssl-3.3.2

# To update symlinks:
# sudo mv /usr/bin/openssl /usr/bin/openssl.bak
# sudo ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl


# OPS Provider

sudo apt update
sudo apt install -y cmake ninja-build build-essential

cd /usr/local/src
sudo git clone https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider

sudo chown -R $USER:$USER /usr/local/src/oqs-provider
export CMAKE_PARAMS="-DOPENSSL_ROOT_DIR=/usr/local/openssl-3.5.2 \
  -DOPENSSL_LIBRARIES=/usr/local/openssl-3.5.2/lib64 \
  -DOPENSSL_INCLUDE_DIR=/usr/local/openssl-3.5.2/include \
  -DCMAKE_BUILD_TYPE=Release"

export OPENSSL_MODULES=/usr/local/src/oqs-provider/_build/lib
/usr/local/openssl-3.5.2/bin/openssl list -signature-algorithms -provider oqsprovider -provider-path $OPENSSL_MODULES
/usr/local/openssl-3.5.2/bin/openssl list -providers -provider oqsprovider

/usr/local/openssl-3.5.2/bin/openssl list -kem-algorithms

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
