# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-sandbox is a tool that runs Claude Code with full autonomy (`--dangerously-skip-permissions`) inside an isolated Docker container.

## Directory Structure

```
claude-sandbox/
├── Dockerfile              # OCI-compatible image definition
├── VERSION                 # Semantic version (shown via --version)
├── .dockerignore           # Files excluded from build context
├── claude-sandbox-dev.sh   # Dev CLI (build/install/uninstall/kill/update)
├── scripts/
│   ├── claude-sandbox-template.sh  # Standalone script template
│   ├── git-readonly-wrapper.sh # Read-only git wrapper for container
│   └── install-claude-code.sh  # Claude Code installer
├── tests/
│   └── smoke-test.sh       # Smoke tests
├── .github/workflows/
│   └── ci.yml              # Shellcheck + Docker build CI
├── SECURITY.md
├── CLAUDE.md
└── README.md
```

## Commands

```bash
# Build/rebuild the container image
./claude-sandbox-dev.sh build

# Install (builds image + installs script to ~/.claude-sandbox/bin/)
./claude-sandbox-dev.sh install

# Remove the container image
./claude-sandbox-dev.sh uninstall

# Force stop running containers
./claude-sandbox-dev.sh kill

# Pull latest + rebuild
./claude-sandbox-dev.sh update
```

## Usage

After installation, the `claude-sandbox` command accepts the following arguments:

```bash
# Run Claude Code in the sandbox
claude-sandbox

# Pass arguments to Claude (e.g., login)
claude-sandbox login

# Drop into a bash shell to inspect the sandbox environment
claude-sandbox shell
```

## Per-Project Configuration

Projects can define named profiles via `.claude-sandbox.json` in the project root:

```json
{
  "dev": {
    "mounts": [
      { "path": "/Volumes/Data/input", "readonly": true },
      { "path": "/Volumes/Data/output" }
    ],
    "ports": [
      { "host": 3000, "container": 3000 }
    ]
  },
  "prod": {
    "mounts": [
      { "path": "/Volumes/Data/prod", "readonly": true }
    ]
  }
}
```

**Fields:**
- Root-level keys are profile names
- `mounts[].path` (required): Absolute host path, mounted to the same path inside the container
- `mounts[].readonly` (optional): If `true`, mount is read-only (default: `false`)
- `ports[].host` (required): Host port number (1-65535)
- `ports[].container` (required): Container port number (1-65535)
- `git_readonly` (optional): If `false`, disables the read-only `.git` mount (default: `true`)
- `network` (optional): Docker network mode — `"bridge"` (default) or `"none"` for full isolation
- `audit_log` (optional): If `true`, enables session audit logging to `~/.claude-sandbox/logs/` (default: `false`)

**Requirements:**
- `jq` must be installed for config parsing (`brew install jq`)
- If `jq` is missing or config is invalid, warnings are shown and extra mounts are skipped

**Path behavior:** The working directory is mounted at its actual path (e.g., `/Users/foo/project` inside and outside). This allows file paths to work identically in both environments.

**Profile selection:**
- With `--profile <name>` or `-p <name>`: Use specified profile
- Without flag: Interactive prompt to select profile

**Usage:**
```bash
claude-sandbox --profile dev      # Use specific profile
claude-sandbox -p prod            # Short form
claude-sandbox                    # Interactive prompt
claude-sandbox --profile dev login  # Profile + args to Claude
```

## Architecture

The project consists of shell scripts that wrap Docker:

- **Dockerfile** - Debian slim image with Claude Code binary installed to `/opt/claude-code/`, entry point runs `claude --dangerously-skip-permissions`
- **claude-sandbox-dev.sh** - Self-contained dev CLI with build, install, uninstall, and kill functions
- **scripts/claude-sandbox-template.sh** - Template for the installed standalone script

### Key Implementation Details

1. **Binary location**: Claude Code is installed to `/opt/claude-code/` (not `~/.claude/`) to avoid collision with the config volume mount at `~/.claude/`. A symlink at `~/.local/bin/claude` points to the binary to satisfy Claude Code's native install detection.

2. **Persisted state**: Two paths are mounted from the host:
   - `~/.claude-sandbox/claude-config` → `/home/claude/.claude` (credentials, cache, settings)
   - `~/.claude-sandbox/.claude.json` → `/home/claude/.claude.json` (session state)

3. **Environment variables** (set in Dockerfile):
   - `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` - Uses system CA certs (Claude Code's bundled certs may be incomplete)
   - `NODE_OPTIONS="--dns-result-order=ipv4first"` - Avoids IPv6 routing issues in Docker

4. **Container lifecycle**: Containers use `--rm` by default for zero overhead. Audit logging (named containers + log dump) is opt-in via `audit_log: true` in profile config.

## Requirements

- [Docker Desktop](https://docs.docker.com/get-docker/) installed and running

## Notifications

Desktop notifications are provided by [claude-code-notify](https://github.com/tsilva/claude-code-notify) (separate project). When sandbox support is enabled during claude-code-notify installation, a TCP listener starts on `localhost:19223`. The container connects via `host.docker.internal`. See README.md for setup instructions.

## Documentation

README.md must be kept up to date with any significant project changes.
