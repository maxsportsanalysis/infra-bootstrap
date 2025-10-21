DEFAULT menu
PROMPT 0
TIMEOUT 50
ONTIMEOUT ubuntu

MENU TITLE PXE Boot Menu

LABEL ubuntu
    MENU LABEL Ubuntu ${k8s_ubuntu_version} Minimal Server
    KERNEL ubuntu/${k8s_ubuntu_version}/vmlinuz
    INITRD ubuntu/${k8s_ubuntu_version}/initrd
    APPEND root=/dev/ram0 ramdisk_size=1500000 ip=dhcp iso-url=https://releases.ubuntu.com/${k8s_ubuntu_version}/ubuntu-${k8s_ubuntu_version}-live-server-amd64.iso \
        autoinstall ds=nocloud-net;s=http://${pxe_server}/autoinstall/ ---

LABEL rescue
    MENU LABEL Rescue / Diagnostics
    KERNEL pxe/rescue/vmlinuz
    INITRD pxe/rescue/initrd
    APPEND ip=dhcp

LABEL local
    MENU LABEL Boot from local disk
    LOCALBOOT 0
