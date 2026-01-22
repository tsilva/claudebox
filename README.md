<div align="center">
  <img src="logo.png" alt="claude-sandbox" width="512"/>

  [![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue?style=flat-square)](https://developer.apple.com/macos/)
  [![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-required-orange?style=flat-square)](https://support.apple.com/en-us/HT211814)
  [![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

  **Run Claude Code with full autonomy inside an isolated container**

  [Quick Start](#quick-start) · [Usage](#usage) · [How It Works](#how-it-works)
</div>

---

## Overview

claude-sandbox lets you run Claude Code with `--dangerously-skip-permissions` safely by isolating it inside Apple's native container technology. Your host system stays protected while Claude works autonomously on your codebase.

## Features

- **True isolation** — Each session runs in its own lightweight Linux VM
- **Fast startup** — Sub-second container boot times on Apple Silicon
- **Pre-built image** — Claude Code ready to go, no install wait
- **Simple workflow** — One command from any project directory

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon (M1/M2/M3/M4)
- [Apple Container CLI](https://github.com/apple/container) installed
- `ANTHROPIC_API_KEY` environment variable set

## Quick Start

```bash
# Clone and install
git clone https://github.com/tsilva/claude-sandbox.git
cd claude-sandbox
./install.sh

# Reload shell
source ~/.zshrc

# Run from any project
cd ~/your-project
claude-sandbox
```

## Usage

After installation, use `claude-sandbox` from any directory:

```bash
cd ~/repos/my-project
claude-sandbox
```

This mounts your current directory as `/workspace` inside the container and launches Claude with autonomous permissions.

### Pass Arguments to Claude

```bash
claude-sandbox -p "Fix all lint errors and run tests"
```

### Rebuild the Image

If you need to update Claude Code to the latest version:

```bash
./build.sh
```

## How It Works

```
┌─────────────────────────────────────┐
│            macOS (Host)             │
│  ┌───────────────────────────────┐  │
│  │    Apple Container (VM)       │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │   Claude Code (auto)    │  │  │
│  │  │  ┌───────────────────┐  │  │  │
│  │  │  │  /workspace       │◄─┼──┼──┼── $(pwd) mounted
│  │  │  │  (your project)   │  │  │  │
│  │  │  └───────────────────┘  │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

- Your project files are mounted read-write at `/workspace`
- Claude runs with `--dangerously-skip-permissions` (no prompts)
- The container is isolated from your host filesystem
- Each container gets its own IP address (no port forwarding needed)

## Scripts

| Script | Description |
|--------|-------------|
| `install.sh` | Build image and add `claude-sandbox` to your shell |
| `build.sh` | Build/rebuild the container image |
| `uninstall.sh` | Remove the container image |

## Safety Notes

While containerized, Claude can still:
- Modify/delete files in your mounted project directory
- Make network requests (API calls, package downloads)

**Recommendations:**
- Commit your work before running autonomous sessions
- Use git to review changes after Claude finishes
- Don't mount directories with sensitive files you don't want modified

## License

MIT

---

<div align="center">
  <sub>README.md must be kept up to date with any significant project changes</sub>
</div>
