#!/bin/bash
#
# kill-containers.sh - Stop all running claude-sandbox Docker containers
#

set -e

# Check if Docker is available
if ! command -v docker &>/dev/null; then
  echo "Error: Docker is not installed or not in PATH"
  exit 1
fi

echo "Finding running claude-sandbox containers..."
# Use label filter for exact match (more reliable than ancestor)
# Fall back to ancestor filter for containers created before label was added
CONTAINERS=$(docker ps -q --filter "ancestor=claude-sandbox" | while read -r id; do
  # Verify this is exactly our image, not a derivative
  img=$(docker inspect --format '{{.Config.Image}}' "$id" 2>/dev/null)
  [ "$img" = "claude-sandbox" ] && echo "$id"
done)

if [ -z "$CONTAINERS" ]; then
    echo "No claude-sandbox containers found running."
    exit 0
fi

echo "Found containers:"
echo "$CONTAINERS" | sed 's/^/  - /'
echo ""

echo "Stopping containers..."
echo "$CONTAINERS" | xargs docker stop

# Check if any are still running and force kill
REMAINING=$(docker ps -q --filter ancestor=claude-sandbox)
if [ -n "$REMAINING" ]; then
    echo "Force killing remaining containers..."
    echo "$REMAINING" | xargs docker kill
fi

echo ""
echo "All claude-sandbox containers stopped."
