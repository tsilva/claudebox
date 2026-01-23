FROM debian:stable-slim

RUN apt-get update && apt-get install -y curl git && rm -rf /var/lib/apt/lists/*

# Create non-root user with UID 501 to match macOS user (for volume permissions)
# claude-code refuses --dangerously-skip-permissions as root
RUN useradd -m -s /bin/bash -u 501 claude
RUN mkdir -p /home/claude/.claude/bin && chown -R claude:claude /home/claude/.claude
USER claude

# Download Claude Code binary directly (skip install script which hangs on `claude install`)
RUN GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases" && \
    VERSION=$(curl -fsSL "$GCS_BUCKET/latest") && \
    echo "Installing Claude Code $VERSION..." && \
    curl -fsSL --progress-bar -o /home/claude/.claude/bin/claude "$GCS_BUCKET/$VERSION/linux-arm64/claude" && \
    chmod +x /home/claude/.claude/bin/claude

WORKDIR /workspace

ENV PATH="/home/claude/.claude/bin:$PATH"

ENTRYPOINT ["claude", "--dangerously-skip-permissions"]
