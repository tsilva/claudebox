#!/bin/bash

# Recreate symlink on tmpfs (rootfs is read-only, ~/.local is a tmpfs)
mkdir -p /home/claude/.local/bin
ln -sf /opt/claude-code/claude /home/claude/.local/bin/claude

if [ -f .venv/bin/activate ]; then
  echo "Activating Python virtual environment (.venv)" >&2
  source .venv/bin/activate
fi
exec claude --dangerously-skip-permissions "$@"
