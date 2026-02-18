# Phase 2: Docker Test Harness

## 1. Objective
Create a local Docker-based SSH server for development and UAT testing that all subsequent SSH-related phases depend on.

## 2. Entry Criteria
1. Phase 1 (Connection Data Model & CRUD) accepted.
2. Connection CRUD is functional.

## 3. Scope In
- Dockerfile with OpenSSH server supporting password and public key authentication.
- docker-compose.yml for easy start/stop.
- start-harness.sh and stop-harness.sh scripts.
- Pre-installed tmux and bash shell.
- Documented credentials, ports, and usage.

## 4. Scope Out
- CI/CD integration (future concern).
- Production server configuration.
- Multiple server configurations (single harness is sufficient).

## 5. Product Requirements
- **PR-1:** Base image is Ubuntu LTS or Alpine with OpenSSH server.
- **PR-2:** SSH server configured to accept password authentication.
- **PR-3:** SSH server configured to accept public key authentication.
- **PR-4:** Test user account exists with a documented username and password.
- **PR-5:** Authorized keys directory is pre-configured for the test user.
- **PR-6:** `tmux` is installed and available on PATH.
- **PR-7:** `bash` is the default shell for the test user.
- **PR-8:** SSH host keys are generated at build time (deterministic for testing).
- **PR-9:** docker-compose.yml defines a single service for the SSH server.
- **PR-10:** SSH port is exposed on a documented host port (e.g., `localhost:2222`).
- **PR-11:** Compose file mounts or copies in `authorized_keys` for public key testing.
- **PR-12:** Health check confirms the SSH port is accepting connections.
- **PR-13:** `start-harness.sh` builds (if needed) and starts the Docker container.
- **PR-14:** `stop-harness.sh` stops and removes the container.
- **PR-15:** Both scripts are idempotent (safe to run multiple times).
- **PR-16:** Both scripts print status messages confirming success or failure.
- **PR-17:** README documents: test username and password, SSH port mapping, how to add public keys, smoke check command, and host address for simulator-to-Docker connectivity.

## 6. UX Requirements
N/A — infrastructure component with no user interface.

## 7. Accessibility Requirements
N/A — infrastructure component with no user interface.

## 8. UAT Checklist
- [ ] UAT-1: Run `start-harness.sh` and confirm the container starts successfully.
- [ ] UAT-2: SSH to `localhost:2222` with documented credentials using a standard SSH client.
- [ ] UAT-3: Verify password authentication works.
- [ ] UAT-4: Add a test public key and verify key authentication works.
- [ ] UAT-5: Run `tmux new-session -s test` inside the container and verify tmux works.
- [ ] UAT-6: Run `stop-harness.sh` and confirm the container stops.
- [ ] UAT-7: Run `start-harness.sh` again and confirm idempotent start.

## 9. Test Allocation
| Type | Scope | Method |
|------|-------|--------|
| Unit | None — infrastructure, not app code | — |
| Critical | SSH port reachable after harness start | Shell smoke test |
| Full | None | — |

## 10. Exit Criteria
1. All UAT checklist items pass.
2. Password authentication works from a standard SSH client.
3. Public key authentication works from a standard SSH client.
4. tmux is available inside the container.
5. Harness can be started by any developer using documented steps.
6. Known gaps documented before Phase 3.

## 11. Step Sequence

### S1: Create Dockerfile with OpenSSH, tmux, bash, and test user
- **Complexity:** medium
- **Deliverable:** `test-harness/Dockerfile`
- **Files:** `test-harness/Dockerfile`
- **Depends on:** none
- **Details:** Use Ubuntu LTS as the base image. Install OpenSSH server, tmux, and bash. Create a test user with a documented password, configure the authorized_keys directory, and enable both password and public key auth in `sshd_config`. Generate SSH host keys at build time for deterministic testing.
- **Acceptance:**
  - [ ] Image builds without errors via `docker build`
  - [ ] `sshd_config` enables password authentication
  - [ ] `sshd_config` enables public key authentication
  - [ ] Test user exists with a documented username and password
  - [ ] `tmux` is available on PATH inside the container
  - [ ] `bash` is the default shell for the test user
  - [ ] SSH host keys are present in the image at build time

### S2: Create docker-compose.yml with port mapping and health check
- **Complexity:** small
- **Deliverable:** `test-harness/docker-compose.yml`
- **Files:** `test-harness/docker-compose.yml`
- **Depends on:** S1
- **Details:** Define a single SSH server service. Map host port 2222 to container port 22. Add a health check that confirms the SSH port is accepting connections. Reference `authorized_keys` via volume or copy-in for public key testing.
- **Acceptance:**
  - [ ] `docker compose up` starts the SSH container
  - [ ] Host port 2222 maps to container port 22
  - [ ] Health check passes once SSH is ready
  - [ ] `authorized_keys` is accessible inside the container for public key testing

### S3: Create start-harness.sh and stop-harness.sh scripts
- **Complexity:** small
- **Deliverable:** `test-harness/start-harness.sh`, `test-harness/stop-harness.sh`
- **Files:** `test-harness/start-harness.sh`, `test-harness/stop-harness.sh`
- **Depends on:** S2
- **Details:** `start-harness.sh` builds the image if not already built, then starts the container, printing status on success or failure. `stop-harness.sh` stops and removes the container, printing status. Both scripts use idempotent checks so they are safe to run multiple times.
- **Acceptance:**
  - [ ] `start-harness.sh` starts the container and prints a success message
  - [ ] `start-harness.sh` exits non-zero and prints an error message on failure
  - [ ] `stop-harness.sh` stops and removes the container and prints a success message
  - [ ] Both scripts are idempotent — re-running does not produce errors

### S4: Verify harness connectivity
- **Complexity:** small
- **Deliverable:** Confirmed working harness (no new files)
- **Files:** none
- **Depends on:** S3
- **Details:** Manual verification using a standard SSH client. Confirm password auth succeeds with documented credentials, add a test public key and confirm key auth succeeds, then verify tmux is available inside the container by running a test session.
- **Acceptance:**
  - [ ] `ssh -p 2222 <testuser>@localhost` succeeds with the documented password
  - [ ] Key authentication succeeds after adding a test public key to `authorized_keys`
  - [ ] `tmux new-session -s test` runs successfully inside the container

### S5: Write test-harness README
- **Complexity:** small
- **Deliverable:** `test-harness/README.md`
- **Files:** `test-harness/README.md`
- **Depends on:** S4
- **Details:** Document everything a new developer needs to use the harness: test username and password, SSH port mapping, how to add public keys for key auth testing, a smoke check command, and the host address for iOS Simulator-to-Docker connectivity.
- **Acceptance:**
  - [ ] README documents the test username and password
  - [ ] README documents the SSH port mapping (`localhost:2222`)
  - [ ] README explains how to add public keys for key auth testing
  - [ ] README provides a smoke check command
  - [ ] README documents the host address for iOS Simulator-to-Docker connectivity
