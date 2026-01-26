#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RUNTIME_CMD="docker"
IMAGE_NAME="claude-sandbox"
FUNCTION_NAME="claude-sandbox"
RUNTIME_NAME="Docker"
INSTALL_HINT="Please install Docker Desktop: https://docs.docker.com/get-docker/"
FUNCTION_COMMENT="Claude Sandbox - run Claude Code in an isolated Docker container"

source "$REPO_ROOT/scripts/common.sh"
do_install
