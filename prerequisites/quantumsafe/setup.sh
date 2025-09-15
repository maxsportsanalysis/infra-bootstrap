#!/bin/bash
set -euo pipefail

# --------- User-configurable ----------
export OPENSSL_VERSION=3.5.2
export LIBOQS_VERSION=0.14.0
export OQSPROVIDER_VERSION=0.10.0
#export CURL_VERSION=8.15.0

export WORKSPACE=$HOME/tmp
export BUILD_DIR=$WORKSPACE/build # this will contain all the build artifacts
export INSTALLDIR_OPENSSL=$WORKSPACE/openssl-$OPENSSL_VERSION
export INSTALLDIR_LIBOQS=$WORKSPACE/liboqs
export INSTALLDIR_OQS_PROVIDER=$WORKSPACE/oqs-provider

# Specify supported signature and key encapsulation mechanisms (KEM) algorithms.
export SIG_ALG="mldsa65" # mldsa65:mldsa87:falcon512
export DEFAULT_GROUPS="x25519:p256_mlkem768:p384_mlkem768:mlkem768:mlkem1024:kyber768"

sudo rm -rf $BUILD_DIR/*
mkdir -p "$WORKSPACE" "$BUILD_DIR" "$INSTALLDIR_OPENSSL" "$INSTALLDIR_LIBOQS"

# --------- Run sibling scripts ---------
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

bash "$SCRIPT_DIR/install_dependencies.sh"
bash "$SCRIPT_DIR/install_openssl.sh"
bash "$SCRIPT_DIR/install_liboqs.sh"
bash "$SCRIPT_DIR/install_oqsprovider.sh"
#bash "$SCRIPT_DIR/full_build.sh"

# --------- Test provider load ---------

# ---------- Notes ----------

# These env vars need to be set for the oqsprovider to be used when using OpenSSL
# export OPENSSL_CONF=$BUILD_DIR/ssl/openssl.cnf
# export OPENSSL_MODULES=$BUILD_DIR/lib
# BUILD_DIR/bin/openssl list -providers -verbose -provider oqsprovider

# Use this OpenSSL in PATH for the rest of the script (without shadowing system)
#export PATH="$BUILD_DIR/bin:$PATH"
#export LD_LIBRARY_PATH="$BUILD_DIR/lib:${LD_LIBRARY_PATH:-}"
#echo "Using openssl: $(which openssl) -> $(openssl version -a | awk 'NR==1')"