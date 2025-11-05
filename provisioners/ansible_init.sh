#!/bin/bash
set -euo pipefail
LOGFILE="/var/log/bootstrap_ansible_env.log"

exec > >(tee -a "$LOGFILE") 2>&1
echo "=== Starting Ansible environment bootstrap at $(date) ==="

# --- Create user if not exists ---
if ! id ansible &>/dev/null; then
  useradd -r -m -d /var/lib/ansible -s /bin/bash ansible
  usermod -aG sudo ansible
  echo "ansible ALL=(ALL) NOPASSWD: /usr/bin/ansible-playbook, /usr/bin/systemctl" > /etc/sudoers.d/ansible
fi

# --- Create venv if missing ---
if [ ! -d /opt/ansible-venv ]; then
  python3 -m venv /opt/ansible-venv
  chown -R ansible:ansible /opt/ansible-venv
  chmod -R 750 /opt/ansible-venv

  /opt/ansible-venv/bin/pip config --global unset global.extra-index-url
  /opt/ansible-venv/bin/pip install --upgrade pip
  /opt/ansible-venv/bin/pip install -r /tmp/requirements.txt
fi

# --- Install Galaxy collections ---
if [ -f /tmp/ansible/collections/requirements.yaml ]; then
  /opt/ansible-venv/bin/ansible-galaxy collection install -r /tmp/anisble/collections/requirements.yaml
fi

# --- Optional cleanup ---
rm -rf tmp/anisble/*

echo "=== Bootstrap complete at $(date) ==="
