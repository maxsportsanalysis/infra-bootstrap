#!/bin/bash

set -o nounset

# Defaults for versions
OPENSSL_VERSION=3.5.2
LIBOQS_VERSION=0.14.0
OQSPROVIDER_VERSION=0.10.0

ver_gte() {
  # usage: ver_gte "1.2.3" "1.2.0"
  # returns 0 if $1 >= $2, 1 otherwise
  # requires sort -V
  [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

# Query GitHub API latest release tag for a repo
get_latest_github_release() {
  local repo=$1
  curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Check and update OPENSSL_VERSION (openssl doesn't have official GH releases; using https://github.com/openssl/openssl)
latest_openssl=$(get_latest_github_release "openssl/openssl")
if [[ -n "$latest_openssl" ]]; then
  # Remove possible leading 'OpenSSL_' or 'v' in tag (adjust if needed)
  latest_openssl="${latest_openssl#OpenSSL_}"
  latest_openssl="${latest_openssl#v}"
  if ! ver_gte "$OPENSSL_VERSION" "$latest_openssl"; then
    export OPENSSL_VERSION="$latest_openssl"
  fi
fi

# Check and update LIBOQS_VERSION
latest_liboqs=$(get_latest_github_release "open-quantum-safe/liboqs")
if [[ -n "$latest_liboqs" ]]; then
  latest_liboqs="${latest_liboqs#v}"
  if ! ver_gte "$LIBOQS_VERSION" "$latest_liboqs"; then
    export LIBOQS_VERSION="$latest_liboqs"
  fi
fi

# Check and update OQSPROVIDER_VERSION (assuming OQSPROVIDER repo is e.g. open-quantum-safe/oqs-provider)
latest_oqsprovider=$(get_latest_github_release "open-quantum-safe/oqs-provider")
if [[ -n "$latest_oqsprovider" ]]; then
  latest_oqsprovider="${latest_oqsprovider#v}"
  if ! ver_gte "$OQSPROVIDER_VERSION" "$latest_oqsprovider"; then
    export OQSPROVIDER_VERSION="$latest_oqsprovider"
  fi
fi

readonly OPENSSL_VERSION
readonly LIBOQS_VERSION
readonly OQSPROVIDER_VERSION

echo "Using OpenSSL version: $OPENSSL_VERSION"
echo "Using liboqs version: $LIBOQS_VERSION"
echo "Using OQS provider version: $OQSPROVIDER_VERSION"