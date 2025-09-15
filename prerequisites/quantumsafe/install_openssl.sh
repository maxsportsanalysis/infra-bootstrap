#!/bin/bash

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
    --openssldir=$INSTALLDIR_OPENSSL/ssl \
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



# no-ssl no-tls no-ssl3 no-tls1 no-tls1_1 no-tls1_2 no-dtls no-dtls1 no-dtls1_2 \
#     no-ssl3-method no-tls1-method no-tls1_1-method no-tls1_2-method no-dtls1-method no-dtls1_2-method \
#     no-md2 no-md4 no-mdc2 no-rc2 no-rc4 no-idea no-bf no-cast no-seed no-rmd160 no-whirlpool \
#     no-gost no-http no-legacy no-integrity-only-ciphers \
#     no-comp no-deprecated no-docs no-dso no-dynamic-engine no-tls-deprecated-ec enable-ec_nistp_64_gcc_128 \
#     no-posix-io no-psk no-rfc3779 no-slh-dsa no-sm2-precomp no-sock no-srp no-srtp no-ssl-trace \
#     no-static-engine no-quic no-thread-pool no-default-thread-pool \
#     no-ts no-ui-console no-uplink disable-weak-ssl-ciphers no-zlib no-zlib-dynamic no-zstd enable-pie \
    