#!/bin/bash
#
# kill-containers.sh - Stop all running claude-sandbox Apple Container instances
#

set -e

echo "Finding running claude-sandbox-apple containers..."
CONTAINERS=$(container ps -q --filter ancestor=claude-sandbox-apple 2>/dev/null)

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
