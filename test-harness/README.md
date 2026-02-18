# Beacon SSH Test Harness

A Docker-based SSH server for local development and testing of Beacon's SSH connectivity features.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running

## Quickstart

```bash
chmod +x test-harness/start-harness.sh
./test-harness/start-harness.sh
```

## Connection Details

| Field    | Value       |
|----------|-------------|
| Host     | `localhost` |
| Port     | `2222`      |
| Username | `testuser`  |
| Password | `testpass`  |

## iOS Simulator Note

The iOS Simulator runs as a process on the Mac host, not inside a VM network, so `localhost` (or `127.0.0.1`) routes correctly to the container's port-mapped SSH service. No special networking configuration is needed.

## Smoke Check

```bash
ssh -p 2222 testuser@localhost
```

Accept the host key fingerprint on first connect.

## Adding a Public Key

To enable public key authentication:

```bash
cat ~/.ssh/id_ed25519.pub >> test-harness/keys/authorized_keys
docker compose -f test-harness/docker-compose.yml restart
```

The `keys/authorized_keys` file is gitignored to avoid committing real credentials.

## Viewing Logs

```bash
docker logs beacon-ssh-test -f
```

## Stopping

```bash
./test-harness/stop-harness.sh
```

## Security Note

This harness is for **local development only**. Never expose port 2222 to the internet.
