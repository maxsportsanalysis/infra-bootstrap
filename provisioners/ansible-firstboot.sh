#!/bin/bash

FLAGFILE=/var/lib/ansible_bootstrap/firstboot.done
PLAYBOOK=/opt/ansible/playbooks/bootstrap.yaml
ANSIBLE_VENV=/opt/ansible-venv

mkdir -p $(dirname "$FLAGFILE")

if [ -f "$FLAGFILE" ]; then
  echo "Bootstrap already completed, skipping."
  exit 0
fi

echo "Running Ansible bootstrap playbook..."

# Activate venv and run playbook locally
source "$ANSIBLE_VENV/bin/activate"
ansible-playbook "$PLAYBOOK" --connection=local

if [ $? -eq 0 ]; then
  echo "Bootstrap successful."
  touch "$FLAGFILE"
else
  echo "Bootstrap failed."
  exit 1
fi