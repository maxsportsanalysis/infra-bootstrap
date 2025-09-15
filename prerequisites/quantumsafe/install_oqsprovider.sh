#!/bin/bash

# ---------- Quantum Safe Provider ----------
echo "Installing Quantum Safe Provider packages (may require sudo)..."

#python3 -m venv $BUILD_DIR/.venv
#$BUILD_DIR/.venv/bin/pip install --no-cache-dir jinja2 tabulate pyyaml
#export PATH="$BUILD_DIR/.venv/bin:$PATH"

cd $BUILD_DIR
git clone --depth 1 --branch ${OQSPROVIDER_VERSION} https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider

#bash "scripts/fullbuild.sh"

#sed -i "s/false/true/g" oqs-template/generate.yml
#LIBOQS_SRC_DIR=$BUILD_DIR/liboqs python3 oqs-template/generate.py

liboqs_DIR=$WORKSPACE/liboqs cmake \
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
export OPENSSL_CONF=$INSTALLDIR_OPENSSL/ssl/openssl.cnf
export LD_LIBRARY_PATH=${INSTALLDIR_LIBOQS}/lib:${INSTALLDIR_OPENSSL}/lib64:${LD_LIBRARY_PATH:-}
export OPENSSL_MODULES=${INSTALLDIR_OPENSSL}/lib64/ossl-modules
#export OPENSSL_MODULES=$INSTALLDIR_OPENSSL/lib64/ossl-modules

echo "Open SSL Modules: $OPENSSL_MODULES"

openssl version && which openssl
openssl list -signature-algorithms -provider oqsprovider -provider-path $OPENSSL_MODULES
