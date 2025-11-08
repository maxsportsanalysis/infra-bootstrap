#!/bin/bash
set -euxo pipefail

# --------- Environment Variables ----------
export OPENSSL_VERSION=3.5.2
export LIBOQS_VERSION=0.14.0
export OQSPROVIDER_VERSION=0.10.0
#export CURL_VERSION=8.15.0

export WORKSPACE=$HOME/tmp
export BUILD_DIR=$WORKSPACE/build
export INSTALLDIR_OPENSSL=$WORKSPACE/openssl-$OPENSSL_VERSION
export INSTALLDIR_LIBOQS=$WORKSPACE/liboqs
export INSTALLDIR_OQS_PROVIDER=$WORKSPACE/oqs-provider

# Specify supported signature and key encapsulation mechanisms (KEM) algorithms.
export SIG_ALG="mldsa65" # mldsa65:mldsa87:falcon512
export DEFAULT_GROUPS="x25519:p256_mlkem768:p384_mlkem768:mlkem768:mlkem1024:kyber768"

sudo rm -rf $BUILD_DIR/*
mkdir -p "$WORKSPACE" "$BUILD_DIR" "$INSTALLDIR_OPENSSL" "$INSTALLDIR_LIBOQS"


# ---------- system deps (needs root) ----------
# Install required build tools and system dependencies (excluding rustc/cargo from apt) - gcc, libunwind-dev, linux-headers-$(uname -r), libssl-dev
echo "Installing system packages (may require sudo)..."
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential clang libtool make gcc ninja-build cmake libtool \
  wget git ca-certificates perl python3 python3-pip python3-venv pkg-config
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*


# ---------- OpenSSL build ----------
echo "Installing OpenSSL (may require sudo)..."
cd $BUILD_DIR
if [ ! -f "openssl-$OPENSSL_VERSION.tar.gz" ]; then
  wget -q "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"
fi
tar -xf "openssl-$OPENSSL_VERSION.tar.gz"
cd openssl-$OPENSSL_VERSION

./config --prefix=$INSTALLDIR_OPENSSL --openssldir=$INSTALLDIR_OPENSSL/ssl \
    no-afalgeng no-shared threads \
    no-ssl no-tls no-ssl3 no-tls1 no-tls1_1 no-tls1_2 no-dtls no-dtls1 no-dtls1_2 \
    no-md2 no-md4 no-mdc2 no-rc2 no-rc4 no-idea no-bf no-cast no-seed no-rmd160 no-whirlpool \
    no-gost no-http no-legacy no-integrity-only-ciphers \
    no-posix-io no-psk no-rfc3779 no-slh-dsa no-sm2-precomp no-sock no-srp no-srtp no-ssl-trace \
    no-static-engine no-quic no-thread-pool no-default-thread-pool \
    no-ts no-ui-console no-uplink disable-weak-ssl-ciphers no-zlib no-zlib-dynamic no-zstd enable-pie \
    no-comp no-deprecated no-docs no-dynamic-engine no-tls-deprecated-ec enable-ec_nistp_64_gcc_128 \
    '-Wl,-rpath,$(LIBRPATH)' -lm

make -j $(nproc)
make -j $(nproc) install_sw install_ssldirs

if [ -d "${INSTALLDIR_OPENSSL}/lib64" ] && [ ! -d "${INSTALLDIR_OPENSSL}/lib" ]; then \
  ln -s "${INSTALLDIR_OPENSSL}/lib64" "${INSTALLDIR_OPENSSL}/lib"; \
fi

"$INSTALLDIR_OPENSSL/bin/openssl" version -a


# ---------- LIBOQS ----------
echo "Installing LIBOQS packages (may require sudo)..."

cd $BUILD_DIR
git clone --depth 1 --branch ${LIBOQS_VERSION} https://github.com/open-quantum-safe/liboqs && \
cd liboqs
mkdir -p build && cd build

cmake -G"Ninja" .. \
  -DOPENSSL_ROOT_DIR=${INSTALLDIR_OPENSSL} \
  -DCMAKE_INSTALL_PREFIX=${INSTALLDIR_OPENSSL} \
  -DBUILD_SHARED_LIBS=ON \
  -DOQS_DIST_BUILD=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DOQS_BUILD_ONLY_LIB=ON

ninja -j"$(nproc)" 
ninja install


# ---------- Quantum Safe Provider ----------

cd $BUILD_DIR
git clone --depth 1 --branch ${OQSPROVIDER_VERSION} https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider


liboqs_DIR=$INSTALLDIR_LIBOQS cmake \
  -DOPENSSL_ROOT_DIR=${INSTALLDIR_OPENSSL} \
  -DOPENSSL_LIBRARIES=${INSTALLDIR_OPENSSL}/lib64 \
  -DOPENSSL_INCLUDE_DIR=${INSTALLDIR_OPENSSL}/include \
  -DCMAKE_PREFIX_PATH=${INSTALLDIR_OPENSSL} \
  -DCMAKE_INSTALL_PREFIX=${INSTALLDIR_OQS_PROVIDER} \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=OFF \
  -S . -B _build && \
  cmake --build _build && \
  cp _build/lib/* $INSTALLDIR_OPENSSL/lib64/ossl-modules && \
    sed -i "s/default = default_sect/default = default_sect\noqsprovider = oqsprovider_sect/g" $INSTALLDIR_OPENSSL/ssl/openssl.cnf && \
    sed -i "s/\[default_sect\]/\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n/g" $INSTALLDIR_OPENSSL/ssl/openssl.cnf && \
    sed -i "s/providers = provider_sect/providers = provider_sect\nssl_conf = ssl_sect\n\n\[ssl_sect\]\nsystem_default = system_default_sect\n\n\[system_default_sect\]\nGroups = \$ENV\:\:DEFAULT_GROUPS\n/g" $INSTALLDIR_OPENSSL/ssl/openssl.cnf && \
    sed -i "s/HOME\t\t\t= ./HOME           = .\nDEFAULT_GROUPS = $DEFAULT_GROUPS/g" $INSTALLDIR_OPENSSL/ssl/openssl.cnf


export PATH="$INSTALLDIR_OPENSSL/bin:$PATH"
export OPENSSL_MODULES="$INSTALLDIR_OPENSSL/lib64/ossl-modules"

echo "Open SSL Modules: $OPENSSL_MODULES"

openssl version && which openssl
openssl list -signature-algorithms -provider oqsprovider -provider-path $OPENSSL_MODULES