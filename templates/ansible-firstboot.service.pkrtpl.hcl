[Unit]
Description=Run Ansible bootstrap playbook on first boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart={{ user `ansible_script_path` }}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target