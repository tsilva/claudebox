#!/bin/bash
if [ -f .venv/bin/activate ]; then
  source .venv/bin/activate
fi
exec claude --dangerously-skip-permissions "$@"
