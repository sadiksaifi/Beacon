#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Stopping Beacon SSH test harness..."

docker compose down

echo "==> SSH test server stopped and removed."
