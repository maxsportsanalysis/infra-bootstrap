#!ipxe
echo "Starting iPXE boot"

dhcp

set base-url http://${next-server}
set k8s_ubuntu_version ${k8s_ubuntu_version}
set k8s_iso_url ${k8s_iso_url}

:menu
menu PXE Boot Menu
item ubuntu   Ubuntu ${k8s_ubuntu_version} Minimal Server
item rescue   Rescue / Diagnostics
item local    Boot from local disk
choose target && goto ${target}

:ubuntu
kernel ${base-url}/pxe/ubuntu/${k8s_ubuntu_version}/vmlinuz root=/dev/ram0 ramdisk_size=1500000 ip=dhcp iso-url=${k8s_iso_url} autoinstall ds=nocloud-net;s=${base-url}/autoinstall/ ---
initrd ${base-url}/pxe/ubuntu/${k8s_ubuntu_version}/initrd
boot

:rescue
kernel ${base-url}/pxe/rescue/vmlinuz initrd=initrd ip=dhcp
initrd ${base-url}/pxe/rescue/initrd
boot

:local
sanboot --no-describe --drive 0x80
