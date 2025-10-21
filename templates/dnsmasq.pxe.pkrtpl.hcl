# ===============================
# dnsmasq.conf – PXE Proxy Setup
# ===============================

# Disable DNS (we're only using DHCP/TFTP)
port=0
log-dhcp
log-facility=/var/log/dnsmasq-pxe.log

# ProxyDHCP mode (router hands out IPs)
dhcp-range=${dhcp_range}
dhcp-no-override

# Enable TFTP
enable-tftp
tftp-root=${tftp_root}

# ------------------------------
# Client Architecture Detection
# ------------------------------
dhcp-match=set:ipxe,175
dhcp-match=set:bios,option:client-arch,0 # BIOS/Legacy x86
dhcp-match=set:efi64,option:client-arch,7 # EFI 64-bit x86 (most modern PCs)

#dhcp-match=set:efi32,option:client-arch,6 # EFI 32-bit x86
#dhcp-match=set:efi64,option:client-arch,9 # EFI 64-bit x86 (network boot)
#dhcp-match=set:efi-arm32,option:client-arch,10 # EFI 32-bit ARM
#dhcp-match=set:efi-arm64,option:client-arch,11 # EFI 64-bit ARMpi

# ------------------------------
# PXE Chainloading Rules
# ------------------------------

# BIOS clients (not yet iPXE)
pxe-service=tag:bios,tag:!ipxe,X86PC,"iPXE (BIOS)",pxelinux.0 # Traditional PXE
pxe-service=tag:bios,tag:!ipxe,X86PC,"iPXE (BIOS)",ipxe/undionly.kpxe # Legacy BIOS w/ iPXE features
pxe-service=tag:efi64,tag:!ipxe,x86-64_EFI,"iPXE (UEFI x64)",ipxe/ipxe.efi # UEFI iPXE x86_64 clients

# Clients already running iPXE send them the script via HTTP
dhcp-boot=tag:ipxe,http://${pxe_server}/ipxe/boot.ipxe