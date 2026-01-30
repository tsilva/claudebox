# Pin base image digest — update periodically via: docker pull debian:stable-slim && docker inspect --format='{{index .RepoDigests 0}}' debian:stable-slim
FROM debian:stable-slim@sha256:7484fda4fd1755b2eb4d8341c5d01dc9de6e31aae805e8ba8e83056906bec11b

ARG USER_UID=1000

COPY VERSION /opt/claude-code/VERSION

LABEL org.opencontainers.image.title="claude-sandbox" \
      org.opencontainers.image.description="Claude Code in an isolated container"

RUN apt-get update && apt-get install -y curl git netcat-openbsd python3 python3-pip python3-venv python-is-python3 && rm -rf /var/lib/apt/lists/*

# Create non-root user with configurable UID for volume permission compatibility
# Claude Code refuses --dangerously-skip-permissions as root
RUN useradd -m -s /bin/bash -u "$USER_UID" claude && \
    mkdir -p /opt/claude-code /home/claude/.local/bin && \
    chown -R claude:claude /opt/claude-code /home/claude/.local
USER claude

# Download Claude Code binary to /opt (separate from config at ~/.claude)
# Detect architecture: map Docker's TARGETARCH to Claude Code's naming convention
RUN GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases" && \
    VERSION=$(curl -fsSL "$GCS_BUCKET/latest") && \
    ARCH=$(uname -m) && \
    case "$ARCH" in \
      x86_64|amd64) CLAUDE_ARCH="linux-x64" ;; \
      aarch64|arm64) CLAUDE_ARCH="linux-arm64" ;; \
      *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    echo "Installing Claude Code $VERSION for $CLAUDE_ARCH..." && \
    curl -fsSL --progress-bar -o /opt/claude-code/claude "$GCS_BUCKET/$VERSION/$CLAUDE_ARCH/claude" && \
    chmod +x /opt/claude-code/claude

# Create symlink at expected native install location
RUN ln -s /opt/claude-code/claude /home/claude/.local/bin/claude

# Install uv (fast Python package installer)
RUN pip3 install --user --break-system-packages uv==0.7.12

WORKDIR /workspace

# Environment configuration:
# - PATH: Include Claude Code binary locations
# - NODE_OPTIONS: Force IPv4 DNS to avoid Docker IPv6 routing issues
# - NODE_EXTRA_CA_CERTS: Use system CA certs (Claude Code's bundled certs may be incomplete)
ENV PATH="/home/claude/.local/bin:/opt/claude-code:$PATH" \
    NODE_OPTIONS="--dns-result-order=ipv4first" \
    NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"

COPY --chown=claude:claude entrypoint.sh /home/claude/entrypoint.sh
RUN chmod +x /home/claude/entrypoint.sh

ENTRYPOINT ["/home/claude/entrypoint.sh"]
