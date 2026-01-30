# =============================================================================
# claude-sandbox Dockerfile
# Runs Claude Code with full autonomy inside an isolated container.
# =============================================================================

# --- Base Image ---
# Debian stable-slim: minimal footprint while providing a full apt ecosystem.
# Pinned by SHA256 digest for reproducible builds — prevents silent breakage
# from upstream tag updates. Refresh periodically via:
#   docker pull debian:stable-slim && docker inspect --format='{{index .RepoDigests 0}}' debian:stable-slim
FROM debian:stable-slim@sha256:7484fda4fd1755b2eb4d8341c5d01dc9de6e31aae805e8ba8e83056906bec11b

# --- Build Arguments ---
# UID for the in-container user. Defaults to 1000 (typical first user on Linux/macOS).
# Configurable so host-mounted volumes have matching file ownership, avoiding
# permission errors when the container writes to bind-mounted directories.
ARG USER_UID=1000

# --- Metadata ---
# Copy the project version file into the image so `claude-sandbox --version`
# can read it at runtime. Stored in /opt/claude-code/ alongside the binary.
COPY VERSION /opt/claude-code/VERSION

# OCI standard labels for container registries and tooling.
LABEL org.opencontainers.image.title="claude-sandbox" \
      org.opencontainers.image.description="Claude Code in an isolated container"

# --- System Dependencies ---
# Install required packages in a single layer to minimize image size:
#   curl             — download Claude Code binary and version manifest
#   git              — Claude Code uses git for project context and diffs
#   jq               — parse JSON manifests (checksum verification) and project configs
#   netcat-openbsd   — TCP connectivity for desktop notification support (port 19223)
#   python3          — required by many Claude Code tool-use workflows
#   python3-pip      — install Python packages (e.g., uv)
#   python3-venv     — create isolated Python environments
#   python-is-python3 — symlinks `python` → `python3` for compatibility
# The apt cache is removed after install to keep the layer small.
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    netcat-openbsd \
    python3 \
    python3-pip \
    python3-venv \
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# --- Git Read-Only Wrapper ---
# Replace the real git binary with a wrapper that only allows read-only
# subcommands. The real binary is preserved at /usr/bin/git.real.
# Both files are root-owned, so the claude user cannot modify or bypass them.
COPY scripts/git-readonly-wrapper.sh /usr/local/bin/git-readonly-wrapper.sh
RUN mv /usr/bin/git /usr/bin/git.real && \
    chmod +x /usr/local/bin/git-readonly-wrapper.sh && \
    ln -s /usr/local/bin/git-readonly-wrapper.sh /usr/bin/git

# --- User Setup ---
# Create a non-root user "claude" with the configurable UID.
# Claude Code refuses to run --dangerously-skip-permissions as root,
# so a regular user is required.
# Pre-create /opt/claude-code (binary install target) and ~/.local/bin
# (symlink location) with correct ownership.
RUN useradd -m -s /bin/bash -u "$USER_UID" claude && \
    mkdir -p /opt/claude-code /opt/uv /home/claude/.local/bin && \
    chown -R claude:claude /opt/claude-code /opt/uv /home/claude/.local

# Switch to non-root user for all subsequent commands.
USER claude

# --- Claude Code Binary Install ---
# Download the Claude Code standalone binary from Google Cloud Storage.
# The install script handles version detection, architecture mapping,
# binary download, and SHA256 checksum verification.
COPY --chown=claude:claude scripts/install-claude-code.sh /tmp/install-claude-code.sh
RUN chmod +x /tmp/install-claude-code.sh && /tmp/install-claude-code.sh && rm /tmp/install-claude-code.sh

# --- Symlink for Native Install Detection ---
# Claude Code checks ~/.local/bin/claude to determine if it's "natively installed".
# This symlink satisfies that check without duplicating the binary.
RUN ln -s /opt/claude-code/claude /home/claude/.local/bin/claude

# --- Python Tooling ---
# Install uv to /opt/uv/ so it persists on a read-only rootfs.
# ~/.local is a tmpfs at runtime, so user-local installs would be lost.
ENV UV_INSTALL_DIR=/opt/uv/bin
RUN curl -LsSf https://astral.sh/uv/0.7.12/install.sh | sh

# --- Working Directory ---
# /workspace is the default working directory. At runtime, the host project
# directory is bind-mounted here (or at its real path for path compatibility).
WORKDIR /workspace

# --- Environment Variables ---
# PATH: include Claude Code binary location and user-local bin (uv, symlink).
# NODE_OPTIONS: force IPv4-first DNS resolution to avoid IPv6 routing failures
#   common inside Docker bridge networks.
# NODE_EXTRA_CA_CERTS: use the system CA certificate bundle instead of
#   Claude Code's bundled certs, which may be incomplete for some environments.
ENV PATH="/home/claude/.local/bin:/opt/uv/bin:/opt/claude-code:$PATH" \
    NODE_OPTIONS="--dns-result-order=ipv4first" \
    NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"

# --- Entrypoint ---
# Copy the entrypoint script and make it executable. The entrypoint handles
# argument parsing (e.g., "shell" for debug access) and launches Claude Code
# with --dangerously-skip-permissions.
COPY --chown=claude:claude entrypoint.sh /home/claude/entrypoint.sh
RUN chmod +x /home/claude/entrypoint.sh

ENTRYPOINT ["/home/claude/entrypoint.sh"]
