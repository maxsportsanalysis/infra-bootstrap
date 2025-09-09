#!/bin/bash
set -euo pipefail

# --------- User-configurable ----------
export OPENSSL_VERSION=3.5.2
export LIBOQS_VERSION=0.14.0
export OQSPROVIDER_VERSION=0.10.0
#export CURL_VERSION=8.15.0

export WORKSPACE=$HOME/tmp
export BUILD_DIR=$WORKSPACE/build # this will contain all the build artifacts
export INSTALLDIR_OPENSSL=/opt/openssl-$OPENSSL_VERSION
export INSTALLDIR_LIBOQS=/opt/liboqs
export INSTALLDIR_OQS_PROVIDER=/opt/oqs-provider

# Specify supported signature and key encapsulation mechanisms (KEM) algorithms.
export SIG_ALG="mldsa65" # mldsa65:mldsa87:falcon512
export DEFAULT_GROUPS="x25519:p256_mlkem768:p384_mlkem768:mlkem768:mlkem1024:kyber768"



# ---------- system deps (needs root) ----------
echo "Installing system packages (may require sudo)..."

# Install required build tools and system dependencies (excluding rustc/cargo from apt) - gcc, libunwind-dev, linux-headers-$(uname -r), libssl-dev
sudo apt-get update
sudo apt-get install -y --no-install-recommends build-essential clang libtool make gcc ninja-build cmake libtool wget git ca-certificates perl python3 python3-pip python3-venv
sudo apt-get clean && rm -rf /var/lib/apt/lists/*


mkdir -p "$WORKSPACE" "$BUILD_DIR" "$INSTALLDIR_OPENSSL" "$INSTALLDIR_LIBOQS"


# ---------- OpenSSL build ----------
echo "Installing OPENSSL (may require sudo)..."
cd $BUILD_DIR
if [ ! -f "openssl-$OPENSSL_VERSION.tar.gz" ]; then
  wget -q "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"
fi
tar -xf "openssl-$OPENSSL_VERSION.tar.gz"

# Build and install OpenSSL, then configure symbolic links.
cd openssl-$OPENSSL_VERSION
  
# https://github.com/openssl/openssl/blob/master/INSTALL.md#configure-openssl (for debugging: enable-trace enable-sslkeylog)
./config --prefix=$INSTALLDIR_OPENSSL \
    no-ssl no-ssl3 no-tls1 no-tls1_1 no-tls1_2 no-dtls no-dtls1 no-dtls1_2 \
    no-ssl3-method no-tls1-method no-tls1_1-method no-tls1_2-method no-dtls1-method no-dtls1_2-method \
    no-md2 no-md4 no-mdc2 no-rc2 no-rc4 no-idea no-bf no-cast no-seed no-rmd160 no-whirlpool \
    no-gost no-http no-legacy no-integrity-only-ciphers \
    no-comp no-deprecated no-docs no-dso no-dynamic-engine no-tls-deprecated-ec enable-ec_nistp_64_gcc_128 \
    no-posix-io no-psk no-rfc3779 no-slh-dsa no-sm2-precomp no-sock no-srp no-srtp no-ssl-trace \
    no-static-engine no-quic no-thread-pool no-default-thread-pool \
    no-ts no-ui-console no-uplink disable-weak-ssl-ciphers no-zlib no-zlib-dynamic no-zstd enable-pie \
    no-afalgeng no-shared threads \
    '-Wl,-rpath,$(LIBRPATH)' -lm

make -j $(nproc)
make -j $(nproc) install_sw install_ssldirs

"$INSTALLDIR_OPENSSL/bin/openssl" version -a


# ---------- LIBOQS ----------
echo "Installing LIBOQS packages (may require sudo)..."

cd $BUILD_DIR
git clone --depth 1 --branch ${LIBOQS_VERSION} https://github.com/open-quantum-safe/liboqs && \
cd liboqs
mkdir build && cd build

cmake -G"Ninja" \
  -DOPENSSL_ROOT_DIR=${INSTALLDIR_OPENSSL} \
  -DCMAKE_INSTALL_PREFIX="${INSTALLDIR_LIBOQS}" \
  -DBUILD_SHARED_LIBS=ON \
  -DOQS_USE_OPENSSL=OFF \
  -DOQS_DIST_BUILD=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DOQS_BUILD_ONLY_LIB=ON \
  -DOQS_DIST_BUILD=ON \
  ..
ninja -j"$(nproc)"
ninja install



# ---------- Quantum Safe Provider ----------
echo "Installing Quantum Safe Provider packages (may require sudo)..."

python3 -m venv $BUILD_DIR/.venv
$BUILD_DIR/.venv/bin/pip install --no-cache-dir jinja2 tabulate pyyaml
export PATH="$BUILD_DIR/.venv/bin:$PATH"

cd $BUILD_DIR
git clone --depth 1 --branch ${OQSPROVIDER_VERSION} https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider

sed -i "s/false/true/g" oqs-template/generate.yml
LIBOQS_SRC_DIR=$BUILD_DIR/liboqs python3 oqs-template/generate.py

liboqs_DIR=${INSTALLDIR_LIBOQS} cmake \
  -DOPENSSL_ROOT_DIR=${INSTALLDIR_OPENSSL} \
  -DOPENSSL_LIBRARIES=${INSTALLDIR_OPENSSL}/lib \
  -DOPENSSL_INCLUDE_DIR=${INSTALLDIR_OPENSSL}/include \
  -DCMAKE_INSTALL_PREFIX=${INSTALLDIR_OQS_PROVIDER} \
  -DCMAKE_BUILD_TYPE=Release \
  -S . -B _build && \
  cmake --build _build && \
  cmake --install _build && \
  cp _build/lib/oqsprovider.so ${INSTALLDIR_OPENSSL}/lib/ossl-modules && \
    sed -i "s/default = default_sect/default = default_sect\noqsprovider = oqsprovider_sect/g" ${INSTALLDIR_OPENSSL}/ssl/openssl.cnf && \
    sed -i "s/\[default_sect\]/\[default_sect\]\nactivate = 1\n\[oqsprovider_sect\]\nactivate = 1\n/g" ${INSTALLDIR_OPENSSL}/ssl/openssl.cnf && \
    sed -i "s/providers = provider_sect/providers = provider_sect\nssl_conf = ssl_sect\n\n\[ssl_sect\]\nsystem_default = system_default_sect\n\n\[system_default_sect\]\nGroups = \$ENV\:\:DEFAULT_GROUPS\n/g" ${INSTALLDIR_OPENSSL}/ssl/openssl.cnf && \
    sed -i "s/HOME\t\t\t= ./HOME           = .\nDEFAULT_GROUPS = ${DEFAULT_GROUPS}/g" ${INSTALLDIR_OPENSSL}/ssl/openssl.cnf

export PATH="${INSTALLDIR_OPENSSL}/bin:${PATH}"




# ---------- Notes ----------

# These env vars need to be set for the oqsprovider to be used when using OpenSSL
# export OPENSSL_CONF=$BUILD_DIR/ssl/openssl.cnf
# export OPENSSL_MODULES=$BUILD_DIR/lib
# BUILD_DIR/bin/openssl list -providers -verbose -provider oqsprovider

# Use this OpenSSL in PATH for the rest of the script (without shadowing system)
#export PATH="$BUILD_DIR/bin:$PATH"
#export LD_LIBRARY_PATH="$BUILD_DIR/lib:${LD_LIBRARY_PATH:-}"
#echo "Using openssl: $(which openssl) -> $(openssl version -a | awk 'NR==1')"

# If you want to temporarily prefer the custom version in your shell: export PATH=/usr/local/openssl-*/bin:$PATH
# Since you didn’t overwrite /usr/bin/openssl, the apt version is still installed. If you ever want to remove your custom build: sudo rm -rf /usr/local/openssl-*
# To update symlinks:
# sudo mv /usr/bin/openssl /usr/bin/openssl.bak
# sudo ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl

# Download and prepare source files needed for the build process.
#RUN git clone --depth 1 --branch ${LIBOQS_TAG} https://github.com/open-quantum-safe/liboqs && \
#    git clone --depth 1 --branch ${OPENSSL_TAG} https://github.com/openssl/openssl.git && \
#    git clone --depth 1 --branch ${OQSPROVIDER_TAG} https://github.com/open-quantum-safe/oqs-provider.git && \
#    wget https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz && tar -zxvf curl-${CURL_VERSION}.tar.gz;
