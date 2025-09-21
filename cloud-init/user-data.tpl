#cloud-config
write_files:
  - path: /opt/bootstrap/bootstrap.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      echo "Running bootstrap with ephemeral secrets..."
      aws secretsmanager get-secret-value \
        --secret-id github-app-token \
        --query SecretString --output text > /opt/bootstrap/github_token.json

runcmd:
  - bash /opt/bootstrap/bootstrap.sh
