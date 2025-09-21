#!/bin/bash
set -euxo pipefail

# Create pxeadmin user and group if it doesn't exist
if ! id -u pxeadmin >/dev/null 2>&1; then
    useradd -m -s /bin/bash pxeadmin
fi

# Update system
apt-get update -y
apt-get upgrade -y

# Install PXE/TFTP/DHCP tools
apt-get install -y dnsmasq tftp-hpa syslinux-common pxelinux nfs-kernel-server

# Create TFTP root
mkdir -p /srv/tftpboot/pxelinux
chown -R pxeadmin:pxeadmin /srv/tftpboot

# Copy PXELINUX bootloader files (from syslinux package) into TFTP root
cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftpboot/pxelinux/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 /srv/tftpboot/pxelinux/
cp /usr/lib/syslinux/modules/bios/menu.c32 /srv/tftpboot/pxelinux/
cp /usr/lib/syslinux/modules/bios/vesamenu.c32 /srv/tftpboot/pxelinux/

# Enable and restart services
systemctl enable dnsmasq
systemctl restart dnsmasq
systemctl enable tftpd-hpa
systemctl restart tftpd-hpa
