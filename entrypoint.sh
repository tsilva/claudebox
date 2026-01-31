#!/bin/bash
set -euo pipefail

# Recreate symlink on tmpfs (rootfs is read-only, ~/.local is a tmpfs)
# The binary lives at /opt/claude-code/ to avoid collision with the config
# volume mount at ~/.claude/, so we symlink it into PATH on every boot.
mkdir -p /home/claude/.local/bin
ln -sf /opt/claude-code/claude /home/claude/.local/bin/claude

# Activate any project-level Python venv so Claude can use project dependencies
if [ -f .venv/bin/activate ]; then
  echo "Activating Python virtual environment (.venv) at $PWD/.venv" >&2
  source .venv/bin/activate
fi

# Replace this process with Claude Code running in fully autonomous mode.
# All remaining arguments (e.g. "login", "shell") are forwarded to the binary.
exec claude --dangerously-skip-permissions "$@"
