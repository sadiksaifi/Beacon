#!/usr/bin/env bash
set -euo pipefail

# Fix ownership and permissions on the bind-mounted .ssh directory.
# Docker bind mounts arrive owned by the host user (often root:root),
# which causes sshd to reject authorized_keys.
chown -R testuser:testuser /home/testuser/.ssh

if [ -f /home/testuser/.ssh/authorized_keys ]; then
    chmod 600 /home/testuser/.ssh/authorized_keys
fi

# Run sshd in the foreground. Docker requires a foreground process.
# -e sends syslog output to stderr so `docker logs` captures it.
exec /usr/sbin/sshd -D -e
