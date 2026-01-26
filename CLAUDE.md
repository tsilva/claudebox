# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-sandbox is a tool that runs Claude Code with full autonomy (`--dangerously-skip-permissions`) inside an isolated container. It supports both Docker and Apple Container CLI runtimes.

## Directory Structure

```
claude-sandbox/
├── Dockerfile              # Shared OCI-compatible image definition
├── docker/                 # Docker runtime scripts
│   ├── build.sh            # Build Docker image
│   ├── install.sh          # Install shell function for Docker
│   ├── kill-containers.sh  # Stop running Docker containers
│   └── uninstall.sh        # Remove Docker image
├── apple/                  # Apple Container CLI scripts (experimental)
│   ├── build.sh            # Build Apple Container image
│   ├── install.sh          # Install shell function for Apple Container
│   ├── kill-containers.sh  # Stop running Apple containers
│   └── uninstall.sh        # Remove Apple Container image
├── CLAUDE.md
└── README.md
```

## Commands

### Docker (Recommended)

```bash
# Build/rebuild the container image
./docker/build.sh

# Install (builds image + adds shell function to .zshrc/.bashrc)
./docker/install.sh

# Remove the container image
./docker/uninstall.sh

# Force stop running containers
./docker/kill-containers.sh
```

### Apple Container CLI (Experimental)

```bash
# Build/rebuild the container image
./apple/build.sh

# Install (builds image + adds shell function to .zshrc/.bashrc)
./apple/install.sh

# Remove the container image
./apple/uninstall.sh

# Force stop running containers
./apple/kill-containers.sh
```

## Usage

After installation, the shell functions accept the following arguments:

```bash
# Run Claude Code in the sandbox
claude-sandbox

# Pass arguments to Claude (e.g., login)
claude-sandbox login

# Drop into a bash shell to inspect the sandbox environment
claude-sandbox shell
```

## Per-Project Configuration

Projects can define additional mounts via `.claude-sandbox.json` in the project root:

```json
{
  "mounts": [
    { "path": "/Volumes/Data/input", "readonly": true },
    { "path": "/Volumes/Data/output" }
  ]
}
```

**Fields:**
- `path` (required): Absolute host path, mounted to the same path inside the container
- `readonly` (optional): If `true`, mount is read-only (default: `false`)

**Requirements:**
- `jq` must be installed for config parsing (`brew install jq`)
- If `jq` is missing or config is invalid, extra mounts are silently skipped

**Path behavior:** The working directory is mounted at its actual path (e.g., `/Users/foo/project` inside and outside). This allows file paths to work identically in both environments.

## Architecture

The project consists of shell scripts that wrap container runtimes:

- **Dockerfile** - Debian slim image with Claude Code binary installed to `/opt/claude-code/`, entry point runs `claude --dangerously-skip-permissions`
- **docker/** - Scripts for Docker runtime, creates `claude-sandbox` shell function
- **apple/** - Scripts for Apple Container CLI, creates `claude-sandbox-apple` shell function

### Key Implementation Details

1. **Binary location**: Claude Code is installed to `/opt/claude-code/` (not `~/.claude/`) to avoid collision with the config volume mount at `~/.claude/`. A symlink at `~/.local/bin/claude` points to the binary to satisfy Claude Code's native install detection.

2. **Persisted state**: Two paths are mounted from the host:
   - `~/.claude-sandbox/claude-config` → `/home/claude/.claude` (credentials, cache, settings)
   - `~/.claude-sandbox/.claude.json` → `/home/claude/.claude.json` (session state)

3. **Environment variables** (set in Dockerfile):
   - `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` - Uses system CA certs (Claude Code's bundled certs may be incomplete)
   - `NODE_OPTIONS="--dns-result-order=ipv4first"` - Avoids IPv6 routing issues in Docker

4. **Container runtimes**:
   - **Docker** (recommended) - Stable, works on all platforms
   - **Apple Container CLI** (experimental) - Requires macOS 26+ and Apple Silicon; may have networking limitations

## Requirements

### Docker (Recommended)
- [Docker Desktop](https://docs.docker.com/get-docker/) installed and running

### Apple Container CLI (Experimental)
- macOS 26 (Tahoe) or later
- Apple Silicon Mac (M1/M2/M3/M4)
- Apple Container CLI: `brew install --cask container`

## Documentation

README.md must be kept up to date with any significant project changes.
