#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"
echo "Pulling latest changes..."
git pull

source "$SCRIPT_DIR/config.sh"
source "$REPO_ROOT/scripts/common.sh"
do_build
