#!/bin/bash
#
# kill-containers.sh - Stop all running claude-sandbox Docker containers
#

set -e

echo "Finding running claude-sandbox containers..."
CONTAINERS=$(docker ps -q --filter ancestor=claude-sandbox)

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
