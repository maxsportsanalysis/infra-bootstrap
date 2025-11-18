[Unit]
Description=Bind Clevis Tang keyslot to encrypted USB
After=network-online.target tangd.socket
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/clevis_bind_usb.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target