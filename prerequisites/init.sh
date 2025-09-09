#!/bin/sh

ROOT_CN="Max's Sports Analysis Root CA"
INTERMEDIATE_CN="Max's Sports Analysis Intermediate CA"
ROOT_DAYS=36500
INTERMEDIATE_DAYS=3650
CLIENT_DAYS=90

openssl genrsa -aes256 -out ca.key.pem 4096
chmod 400 ca.key.pem

openssl req -x509 -new -sha256 -days 36500 \
  -key ca.key.pem \
  -out ca.cert.pem \
  -subj "/CN=MyRootCA/O=MyOrg/C=US"
chmod 444 ca.cert.pem

sudo cryptsetup open /dev/sdX myusb
sudo mkfs.ext4 /dev/mapper/myusb   # only if not formatted yet!
sudo mkdir -p /mnt/myusb
sudo mount /dev/mapper/myusb /mnt/myusb

sudo cp ca.key.pem ca.cert.pem /mnt/myusb/

sudo umount /mnt/myusb
sudo cryptsetup close myusb

# Your private key (ca.key.pem) is encrypted with AES-256 and sitting on a LUKS-encrypted USB.
# Your public cert (ca.cert.pem) is also on the USB (safe to copy elsewhere, e.g. upload to AWS as trust anchor).

# openssl genrsa -aes256 -out ca.key.pem 4096 && \
#openssl req -x509 -new -sha256 -days 36500 -key ca.key.pem -out ca.cert.pem -subj "/CN=MyRootCA/O=MyOrg/C=US"

# For Post-Quantum Cryptography (PQC) provider in OpenSSL: https://github.com/open-quantum-safe/oqs-provider