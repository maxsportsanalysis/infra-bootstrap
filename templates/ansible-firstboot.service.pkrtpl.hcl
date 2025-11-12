[Unit]
Description=Run Ansible bootstrap playbook on first boot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart={{ user `ansible_script_path` }}
Environment=DEFAULT_VAULT_PASSWORD_FILE={{ user `ansible_password_path` }}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target