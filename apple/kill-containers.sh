#!/bin/bash
#
# kill-containers.sh - Stop all running claude-sandbox Apple Container instances
#

set -e

# Check if Apple Container CLI is available
if ! command -v container &>/dev/null; then
  echo "Error: Apple Container CLI is not installed or not in PATH"
  echo "Please install with: brew install --cask container"
  exit 1
fi

echo "Finding running claude-sandbox-apple containers..."
# Use ancestor filter and verify exact image match
CONTAINERS=$(container ps -q --filter ancestor=claude-sandbox-apple 2>/dev/null | while read -r id; do
  # Verify this is exactly our image, not a derivative
  img=$(container inspect --format '{{.Config.Image}}' "$id" 2>/dev/null)
  [ "$img" = "claude-sandbox-apple" ] && echo "$id"
done)

if [ -z "$CONTAINERS" ]; then
    echo "No claude-sandbox-apple containers found running."
    exit 0
fi

echo "Found containers:"
echo "$CONTAINERS" | sed 's/^/  - /'
echo ""

echo "Stopping containers..."
for c in $CONTAINERS; do
    container stop "$c" || container kill "$c"
done

echo ""
echo "All claude-sandbox-apple containers stopped."
