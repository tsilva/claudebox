#!/usr/bin/env bash
# =============================================================================
# install-claude-code.sh
# Downloads and verifies the Claude Code standalone binary from Google Cloud
# Storage. Installs to /opt/claude-code/claude.
# =============================================================================
set -euo pipefail

# GCS bucket hosting Claude Code release artifacts.
GCS_BUCKET="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

# Fetch the latest release version string.
VERSION=$(curl -fsSL "$GCS_BUCKET/latest")

# Map host CPU architecture to Claude Code's platform naming convention.
ARCH=$(uname -m)
case "$ARCH" in
  x86_64|amd64)   CLAUDE_ARCH="linux-x64" ;;
  aarch64|arm64)   CLAUDE_ARCH="linux-arm64" ;;
  *) echo "Unsupported architecture: $ARCH" && exit 1 ;;
esac

echo "Installing Claude Code $VERSION for $CLAUDE_ARCH..."

# Download the binary to /opt/claude-code/ (separate from ~/.claude config).
curl -fsSL --progress-bar -o /opt/claude-code/claude "$GCS_BUCKET/$VERSION/$CLAUDE_ARCH/claude"
chmod +x /opt/claude-code/claude

# Verify SHA256 checksum against the signed release manifest.
EXPECTED_SHA=$(curl -fsSL "$GCS_BUCKET/$VERSION/manifest.json" | jq -r ".platforms[\"$CLAUDE_ARCH\"].checksum")
ACTUAL_SHA=$(sha256sum /opt/claude-code/claude | cut -d' ' -f1)

if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
  echo "Checksum mismatch! Expected: $EXPECTED_SHA, Got: $ACTUAL_SHA"
  exit 1
fi

echo "Checksum verified: $ACTUAL_SHA"
