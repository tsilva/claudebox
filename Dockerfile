FROM debian:stable-slim

RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

# Create non-root user with UID 501 to match macOS user (for volume permissions)
# claude-code refuses --dangerously-skip-permissions as root
RUN useradd -m -s /bin/bash -u 501 claude
RUN mkdir -p /opt/claude-code && chown claude:claude /opt/claude-code
RUN mkdir -p /home/claude/.local/bin && chown -R claude:claude /home/claude/.local
USER claude

# Download Claude Code binary to /opt (separate from config at ~/.claude)
RUN GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases" && \
    VERSION=$(curl -fsSL "$GCS_BUCKET/latest") && \
    echo "Installing Claude Code $VERSION..." && \
    curl -fsSL --progress-bar -o /opt/claude-code/claude "$GCS_BUCKET/$VERSION/linux-arm64/claude" && \
    chmod +x /opt/claude-code/claude

# Create symlink at expected native install location
RUN ln -s /opt/claude-code/claude /home/claude/.local/bin/claude

WORKDIR /workspace

# Force IPv4 for DNS to avoid Docker IPv6 routing issues
# Use system CA certs (Claude Code's bundled certs may be incomplete)
ENV PATH="/home/claude/.local/bin:/opt/claude-code:$PATH"
ENV NODE_OPTIONS="--dns-result-order=ipv4first"
ENV NODE_EXTRA_CA_CERTS="/etc/ssl/certs/ca-certificates.crt"

ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
