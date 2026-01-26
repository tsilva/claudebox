<div align="center">
  <img src="logo.png" alt="claude-sandbox" width="512"/>

  # claude-sandbox

  [![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
  [![Apple Container](https://img.shields.io/badge/Apple_Container-Experimental-000000?logo=apple&logoColor=white)](https://developer.apple.com/documentation/virtualization)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

  **Run Claude Code with full autonomy inside an isolated container — let it code freely without touching your system**

  [Docker](https://docs.docker.com/get-docker/) · [Claude Code](https://claude.ai/code) · [Apple Container CLI](https://developer.apple.com/documentation/virtualization)
</div>

## Overview

claude-sandbox runs [Claude Code](https://claude.ai/code) with `--dangerously-skip-permissions` inside an isolated container. This gives Claude full autonomy to install packages, run commands, and modify files — all safely contained without access to your host system.

## Features

- **Isolated execution** — Claude runs in a container with no access to your host filesystem (except mounted paths)
- **Full autonomy** — No permission prompts; Claude can execute any command inside the sandbox
- **Same-path mounting** — Your project directory is mounted at its actual path, so file paths work identically inside and outside the container
- **Per-project configuration** — Define additional mounts via `.claude-sandbox.json` for data directories, output folders, etc.
- **Simple setup** — One install script adds a shell function you can run from any project
- **Multiple runtimes** — Choose Docker (cross-platform) or Apple Container CLI (macOS 26+)

## Quick Start

### Docker (Recommended)

```bash
git clone https://github.com/tsilva/claude-sandbox.git
cd claude-sandbox
./docker/install.sh
source ~/.zshrc  # or ~/.bashrc
```

Then authenticate once (uses your Claude Pro/Max subscription):

```bash
claude-sandbox login
```

And from any project directory:

```bash
cd ~/my-project
claude-sandbox
```

### Apple Container CLI (Experimental)

Requires macOS 26 (Tahoe) or later on Apple Silicon.

```bash
# Install Apple Container CLI
brew install --cask container
container system start

# Install claude-sandbox-apple
git clone https://github.com/tsilva/claude-sandbox.git
cd claude-sandbox
./apple/install.sh
source ~/.zshrc  # or ~/.bashrc
```

Then authenticate and use:

```bash
claude-sandbox-apple login
cd ~/my-project
claude-sandbox-apple
```

## Requirements

| Runtime | Requirements |
|---------|--------------|
| **Docker** (Recommended) | [Docker Desktop](https://docs.docker.com/get-docker/) on macOS, Linux, or Windows with WSL |
| **Apple Container** (Experimental) | macOS 26+, Apple Silicon (M1/M2/M3/M4), `brew install --cask container` |

**Optional:** `jq` for per-project configuration support (`brew install jq`)

## Per-Project Configuration

Create a `.claude-sandbox.json` file in your project root to mount additional directories:

```json
{
  "mounts": [
    { "path": "/Volumes/Data/input", "readonly": true },
    { "path": "/Volumes/Data/output" }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `path` | Yes | Absolute host path (mounted to the same path inside container) |
| `readonly` | No | If `true`, mount is read-only (default: `false`) |

**Example use case:** A data processing project that reads from an external drive and writes results:

```json
{
  "mounts": [
    { "path": "/Volumes/ExternalDrive/datasets", "readonly": true },
    { "path": "/Users/me/outputs" }
  ]
}
```

**Note:** Requires `jq` to be installed. If `jq` is missing or the config file is invalid, extra mounts are silently skipped and the sandbox runs normally.

## Commands

### Docker

| Script | Purpose |
|--------|---------|
| `./docker/install.sh` | Build image and add `claude-sandbox` shell function |
| `./docker/build.sh` | Rebuild the container image |
| `./docker/uninstall.sh` | Remove the container image |
| `./docker/kill-containers.sh` | Force stop any running containers |

### Apple Container CLI

| Script | Purpose |
|--------|---------|
| `./apple/install.sh` | Build image and add `claude-sandbox-apple` shell function |
| `./apple/build.sh` | Rebuild the container image |
| `./apple/uninstall.sh` | Remove the container image |
| `./apple/kill-containers.sh` | Force stop any running containers |

## Authentication

claude-sandbox uses your Claude Pro/Max subscription instead of API keys. On first use, authenticate via browser:

```bash
claude-sandbox login        # Docker
claude-sandbox-apple login  # Apple Container
```

This opens a browser window for OAuth authentication. Your credentials are stored in `~/.claude-sandbox/` and persist across all container sessions — you only need to log in once.

## Usage

```bash
# Run Claude Code in the sandbox
claude-sandbox

# Pass arguments to Claude (e.g., login)
claude-sandbox login

# Drop into a bash shell to inspect the sandbox environment
claude-sandbox shell
```

The `shell` argument is useful for debugging or exploring what tools and files are available inside the container.

## How It Works

```mermaid
graph LR
    A[Your Project] -->|mount at same path| B[Container]
    B --> C[Claude Code]
    C -->|full autonomy| D[Execute Commands]
    D -->|changes| A
```

1. **install.sh** builds an OCI-compatible image with Claude Code pre-installed
2. Running `claude-sandbox` starts a container with your current directory mounted at its actual path
3. Claude Code runs with `--dangerously-skip-permissions` inside the isolated environment
4. All changes to the mounted directory are reflected in your project
5. Optional: `.claude-sandbox.json` adds extra mounts for data directories

## Project Structure

```
claude-sandbox/
├── Dockerfile              # Shared OCI-compatible image definition
├── scripts/
│   └── common.sh           # Shared functions for all runtime scripts
├── docker/                 # Docker runtime scripts
│   ├── config.sh           # Docker-specific configuration
│   ├── build.sh
│   ├── install.sh
│   ├── uninstall.sh
│   └── kill-containers.sh
├── apple/                  # Apple Container CLI scripts
│   ├── config.sh           # Apple Container-specific configuration
│   ├── build.sh
│   ├── install.sh
│   ├── uninstall.sh
│   └── kill-containers.sh
└── README.md
```

The `docker/` and `apple/` scripts are thin wrappers (~15 lines each) that set configuration variables and delegate to shared functions in `scripts/common.sh`. This ensures consistent behavior across runtimes while minimizing code duplication.

## Troubleshooting

### Docker: "ETIMEDOUT" or "Unable to connect to Anthropic services"

This usually means you're using Apple Container CLI instead of Docker. Verify you're using Docker:

```bash
which docker  # Should show Docker path
type claude-sandbox  # Should show 'docker run', not 'container run'
```

If the function shows `container run`, update it to use `docker run` instead, or use the dedicated `claude-sandbox-apple` function for Apple Container.

### "Configuration file corrupted" on first run

The `.claude.json` file needs to be valid JSON. Reset it:

```bash
echo '{}' > ~/.claude-sandbox/.claude.json
```

### Login doesn't persist

Make sure both config paths are mounted. Check your shell function includes:
- `-v ~/.claude-sandbox/claude-config:/home/claude/.claude`
- `-v ~/.claude-sandbox/.claude.json:/home/claude/.claude.json`

### Per-project mounts not working

1. Verify `jq` is installed: `which jq` or `brew install jq`
2. Validate your config: `jq . .claude-sandbox.json`
3. Check paths are absolute (start with `/`)

### Apple Container: Networking issues

Apple Container CLI may have networking limitations depending on macOS version. If you experience connectivity issues, try Docker instead or ensure you're running macOS 26 (Tahoe) or later.

## License

MIT
