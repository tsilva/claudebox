#!/bin/bash
if [ -f .venv/bin/activate ]; then
  echo "Activating Python virtual environment (.venv)" >&2
  source .venv/bin/activate
fi
exec claude --dangerously-skip-permissions --plan "$@"
