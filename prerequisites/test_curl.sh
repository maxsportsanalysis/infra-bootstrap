#!/bin/sh

# When using OpenSSL, cURL can be called with a --curves parameter that specifies which OpenSSL algorithm to use for encryption. This allows us to test our OpenSSL installation quickly.
# As of version 8.4.0, cURL has no way to easily find out if a quantum-safe algorithm was successfully used when the curve is specified. This has been addressed in an unreleased commit which has added the encryption algorithms used in the verbose output.

cd $WORKSPACE

git clone https://github.com/curl/curl.git
cd curl

#OPTIONAL# git checkout 0eda1f6c9

autoreconf -fi
./configure \
  LIBS="-lssl -lcrypto -lz" \
  LDFLAGS="-Wl,-rpath,$BUILD_DIR/lib64 -L$BUILD_DIR/lib64 -Wl,-rpath,$BUILD_DIR/lib -L$BUILD_DIR/lib -Wl,-rpath,/lib64 -L/lib64 -Wl,-rpath,/lib -L/lib" \
  CFLAGS="-O3 -fPIC" \
  --prefix=$BUILD_DIR \
  --with-ssl=$BUILD_DIR \
  --with-zlib=/ \
  --enable-optimize --enable-libcurl-option --enable-libgcc --enable-shared \
  --enable-ldap=no --enable-ipv6 --enable-versioned-symbols \
  --disable-manual \
  --without-default-ssl-backend \
  --without-librtmp --without-libidn2 \
  --without-gnutls --without-mbedtls \
  --without-wolfssl --without-libpsl

make -j $(nproc)
make -j $(nproc) install