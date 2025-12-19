# Bootstrap Infrastructure

## USB Devices
1. DMI USB for Root CA keyfile - /dev/disk/by-id/usb-Generic_Flash_Disk_6D6BCE7D-0:0
2. Continental Honda USB for Root CA - /dev/disk/by-id/usb-General_UDisk-0:0
3. Green 4GB USB - /dev/disk/by-id/usb-Memorex_Mini_079B1503EC7797C0-0:0
4. Black 16GB Sliding Cover USB - /dev/disk/by-id/usb-SMI_USB_DISK-0:0

### Forensic Wipe
sudo shred --verbose --iterations=3 /dev/sdX
sudo cryptsetup luksFormat /dev/sdX
sudo cryptsetup open /dev/sdX wiped
sudo dd if=/dev/zero of=/dev/mapper/wiped status=progress bs=4M
sudo cryptsetup close wiped

```bash
sudo ./create_secure_root_ca.sh <root_block_device> <keyfile_block_device>
sudo ./create_secure_root_ca.sh /dev/disk/by-id/usb-General_UDisk-0:0 /dev/disk/by-id/usb-Generic_Flash_Disk_6D6BCE7D-0:0
sudo ./create_secure_root_ca.sh /dev/disk/by-id/usb-Memorex_Mini_079B1503EC7797C0-0:0 /dev/disk/by-id/usb-General_UDisk-0:0

```