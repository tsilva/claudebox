#!/bin/bash
#
# kill-containers.sh - Force stop Apple Container CLI services
#
# WHY THIS EXISTS:
# Apple's Container CLI (https://github.com/apple/container) has a known bug
# where `container system stop` and `container stop --all` don't actually stop
# containers. The processes keep respawning because they're managed by launchd.
#
# Related issues:
# - https://github.com/apple/container/issues/861 (Cannot Stop or Uninstall)
# - https://github.com/apple/container/issues/946 (Stop commands don't work)
#
# This script unloads the launchd services directly, which actually stops them.
#

set -e

USER_ID=$(id -u)
DOMAIN="gui/${USER_ID}"

echo "Finding Apple Container launchd services..."
SERVICES=$(launchctl list | grep 'com\.apple\.container\.' | awk '{print $3}' | grep -v containermanagerd || true)

if [ -z "$SERVICES" ]; then
    echo "No Apple Container services found running."
    exit 0
fi

echo "Found services:"
echo "$SERVICES" | sed 's/^/  - /'
echo ""

echo "Stopping services via launchctl bootout..."
for service in $SERVICES; do
    echo "  Stopping: $service"
    launchctl bootout "$DOMAIN" "$service" 2>/dev/null || echo "    (already stopped or failed)"
done

echo ""
echo "Verifying..."
REMAINING=$(launchctl list | grep 'com\.apple\.container\.' | grep -v containermanagerd || true)

if [ -z "$REMAINING" ]; then
    echo "All Apple Container services stopped."
else
    echo "Some services may still be running:"
    echo "$REMAINING"
    echo ""
    echo "Try rebooting if services persist."
fi
