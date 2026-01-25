# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-sandbox is a tool that runs Claude Code with full autonomy (`--dangerously-skip-permissions`) inside an isolated Docker container. It works on any system with Docker installed.

## Commands

```bash
# Build/rebuild the container image
./build.sh

# Install (builds image + adds shell function to .zshrc/.bashrc)
./install.sh

# Remove the container image
./uninstall.sh

# Force stop running containers
./kill-containers.sh
```

## Architecture

The project consists of shell scripts that wrap Docker:

- **Dockerfile** - Debian slim image with Claude Code binary installed to `/opt/claude-code/`, entry point runs `claude --dangerously-skip-permissions`
- **install.sh** - Builds the image and injects a `claude-sandbox` shell function that mounts the current directory as `/workspace`
- **kill-containers.sh** - Stops all running claude-sandbox Docker containers

### Key Implementation Details

1. **Binary location**: Claude Code is installed to `/opt/claude-code/` (not `~/.claude/`) to avoid collision with the config volume mount at `~/.claude/`. A symlink at `~/.local/bin/claude` points to the binary to satisfy Claude Code's native install detection.

2. **Persisted state**: Two paths are mounted from the host:
   - `~/.claude-sandbox/claude-config` → `/home/claude/.claude` (credentials, cache, settings)
   - `~/.claude-sandbox/.claude.json` → `/home/claude/.claude.json` (session state)

3. **Environment variables** (set in Dockerfile):
   - `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` - Uses system CA certs (Claude Code's bundled certs may be incomplete)
   - `NODE_OPTIONS="--dns-result-order=ipv4first"` - Avoids IPv6 routing issues in Docker

4. **Container runtime**: Must use Docker, not Apple Container CLI (`container` command) - the latter has networking issues that cause ETIMEDOUT errors

## Requirements

- [Docker Desktop](https://docs.docker.com/get-docker/) installed and running (not Apple Container CLI)

## Documentation

README.md must be kept up to date with any significant project changes.
