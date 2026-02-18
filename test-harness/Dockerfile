FROM ubuntu:24.04

# Avoid interactive prompts during package install
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    tmux \
    bash \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Create the test user with a known password and bash as its shell
RUN useradd -m -s /bin/bash testuser \
    && echo 'testuser:testpass' | chpasswd

# Configure sshd
RUN mkdir -p /var/run/sshd
COPY sshd_config /etc/ssh/sshd_config

# Generate host keys at build time so they are baked into the image layer.
# This means the container presents the same fingerprints across restarts
# (only rotating on a full image rebuild).
RUN ssh-keygen -A

# Prepare .ssh directory for the test user.
# Ownership and permissions of authorized_keys are fixed at runtime
# by the entrypoint because a bind mount may arrive as root-owned.
RUN mkdir -p /home/testuser/.ssh \
    && chmod 700 /home/testuser/.ssh \
    && chown testuser:testuser /home/testuser/.ssh

# Copy and wire up the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
