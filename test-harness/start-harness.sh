#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Starting Beacon SSH test harness..."

# Ensure the keys directory exists (in case the bind mount target is missing)
mkdir -p keys

docker compose up -d --build

echo ""
echo "==> SSH test server is running."
echo "    Host:     localhost"
echo "    Port:     2222"
echo "    Username: testuser"
echo "    Password: testpass"
echo ""
echo "    Smoke check:"
echo "      ssh -p 2222 testuser@localhost"
echo ""
echo "    To add a public key for key auth:"
echo "      cat ~/.ssh/id_ed25519.pub >> test-harness/keys/authorized_keys"
echo "      docker compose restart   # or stop/start"
