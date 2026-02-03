#!/usr/bin/env bash
set -euo pipefail

# claude-sandbox one-liner installer
# Usage: curl -fsSL https://raw.githubusercontent.com/tsilva/claude-sandbox/main/install.sh | bash

REPO_URL="https://github.com/tsilva/claude-sandbox.git"
INSTALL_DIR="${HOME}/.claude-sandbox/repo"

echo "Installing claude-sandbox..."

# Clone or update repo
if [[ -d "$INSTALL_DIR" ]]; then
    echo "Updating existing installation..."
    git -C "$INSTALL_DIR" pull --ff-only
else
    echo "Cloning repository..."
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Run the installer
cd "$INSTALL_DIR"
./claude-sandbox-dev.sh install

echo ""
echo "Installation complete!"
echo "Run 'source ~/.zshrc' (or ~/.bashrc), then:"
echo "  claude-sandbox login    # authenticate once"
echo "  claude-sandbox          # start coding"
