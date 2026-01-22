# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

claude-sandbox is a tool that runs Claude Code with full autonomy (`--dangerously-skip-permissions`) inside an isolated Apple Container (lightweight Linux VM). It requires macOS 26+ on Apple Silicon.

## Commands

```bash
# Build/rebuild the container image
./build.sh

# Install (builds image + adds shell function to .zshrc/.bashrc)
./install.sh

# Remove the container image
./uninstall.sh

# Force stop stuck containers (workaround for apple/container bug)
./kill-containers.sh
```

## Architecture

The project consists of shell scripts that wrap Apple's Container CLI:

- **Dockerfile** - Node.js LTS image with Claude Code globally installed, entry point runs `claude --dangerously-skip-permissions`
- **install.sh** - Builds the image and injects a `claude-sandbox` shell function that mounts the current directory as `/workspace` and passes through `ANTHROPIC_API_KEY`
- **kill-containers.sh** - Directly unloads launchd services to work around [apple/container#861](https://github.com/apple/container/issues/861) where normal stop commands don't work

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon (M1/M2/M3/M4)
- [Apple Container CLI](https://github.com/apple/container) installed
- `ANTHROPIC_API_KEY` environment variable set

## Documentation

README.md must be kept up to date with any significant project changes.
