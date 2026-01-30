<div align="center">
  <img src="logo.png" alt="claude-sandbox" width="512"/>

  # claude-sandbox

  [![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

  **🐳 Run Claude Code with full autonomy inside an isolated container — let it code freely without touching your system**

  [Docker](https://docs.docker.com/get-docker/) · [Claude Code](https://claude.ai/code)
</div>

---

## 📑 Table of Contents

- [✨ Features](#-features)
- [🚀 Quick Start](#-quick-start)
- [📋 Requirements](#-requirements)
- [🔐 Authentication](#-authentication)
- [💻 Usage](#-usage)
- [⚙️ Per-Project Configuration](#️-per-project-configuration)
- [🐳 Per-Project Dockerfile](#-per-project-dockerfile)
- [🛠️ Commands](#️-commands)
- [🔍 How It Works](#-how-it-works)
- [📁 Project Structure](#-project-structure)
- [🔧 Troubleshooting](#-troubleshooting)
- [🔔 Notifications](#-notifications)
- [🔒 Security](#-security)
- [📄 License](#-license)

## ✨ Features

- **🔒 Isolated execution** — Claude runs in a container with no access to your host filesystem (except mounted paths)
- **⚡ Full autonomy** — No permission prompts; Claude can execute any command inside the sandbox
- **📂 Same-path mounting** — Your project directory is mounted at its actual path, so file paths work identically inside and outside the container
- **🎛️ Per-project configuration** — Define additional mounts and ports via `.claude-sandbox.json` for data directories, output folders, and more
- **🏗️ Per-project Dockerfile** — Customize the container with project-specific dependencies using `.claude-sandbox.Dockerfile`
- **🧩 Plugin support** — Marketplace plugins from `~/.claude/plugins/marketplaces` are mounted read-only into the container
- **🎯 Simple setup** — One install script adds a standalone command you can run from any project

## 🚀 Quick Start

```bash
git clone https://github.com/tsilva/claude-sandbox.git
cd claude-sandbox
./claude-sandbox-dev.sh install
source ~/.zshrc  # or ~/.bashrc
```

Then authenticate once (uses your Claude Pro/Max subscription):

```bash
claude-sandbox login
```

Now head to any project directory and start coding:

```bash
cd ~/my-project
claude-sandbox
```

## 📋 Requirements

- [Docker Desktop](https://docs.docker.com/get-docker/) on macOS (Linux/WSL2 not yet supported)
- **Optional:** `jq` for per-project configuration support (`brew install jq`)

## 🔐 Authentication

claude-sandbox uses your Claude Pro/Max subscription instead of API keys. On first use, authenticate via browser:

```bash
claude-sandbox login
```

This opens a browser window for OAuth authentication. Your credentials are stored in `~/.claude-sandbox/` and persist across all container sessions — you only need to log in once.

## 💻 Usage

```bash
# Run Claude Code in the sandbox
claude-sandbox

# Pass arguments to Claude (e.g., login)
claude-sandbox login

# Drop into a bash shell to inspect the sandbox environment
claude-sandbox shell

# With profiles (see Per-Project Configuration)
claude-sandbox --profile dev       # Use specific profile
claude-sandbox -p prod             # Short form
claude-sandbox --profile dev login # Profile + args to Claude

# Print the full docker run command without executing
claude-sandbox --dry-run
```

💡 The `shell` argument is useful for debugging or exploring what tools and files are available inside the container.

## ⚙️ Per-Project Configuration

Create a `.claude-sandbox.json` file in your project root to define named profiles with mounts and ports:

```json
{
  "dev": {
    "mounts": [
      { "path": "/Volumes/Data/input", "readonly": true },
      { "path": "/Volumes/Data/output" }
    ],
    "ports": [
      { "host": 3000, "container": 3000 },
      { "host": 5173, "container": 5173 }
    ]
  },
  "prod": {
    "mounts": [
      { "path": "/Volumes/Data/prod", "readonly": true }
    ]
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `<profile-name>` | Yes | Root-level keys are profile names |
| `mounts[].path` | Yes | Absolute host path (mounted to the same path inside container) |
| `mounts[].readonly` | No | If `true`, mount is read-only (default: `false`) |
| `ports[].host` | Yes | Host port number (1-65535) |
| `ports[].container` | Yes | Container port number (1-65535) |
| `git_readonly` | No | If `false`, disables read-only `.git` mount (default: `true`) |
| `network` | No | Docker network mode: `"bridge"` (default) or `"none"` for isolation |
| `audit_log` | No | If `true`, saves session logs to `~/.claude-sandbox/logs/` (default: `false`) |

🔒 **Git safety:** A read-only git wrapper inside the container blocks write operations (`commit`, `push`, `add`, `reset`, etc.) while allowing reads (`status`, `log`, `diff`, `blame`, etc.). This applies to all git repositories accessible in the container. To allow git writes, set `"git_readonly": false` in your profile config.

**Profile selection:**
- **With `--profile`**: Use the specified profile directly
- **Without flag**: Interactive numbered menu

```bash
claude-sandbox --profile dev   # Use specific profile
claude-sandbox -p prod         # Short form
claude-sandbox                 # Interactive prompt to select profile
```

**Example use case:** A data processing project with dev and prod environments:

```json
{
  "dev": {
    "mounts": [
      { "path": "/Volumes/ExternalDrive/datasets", "readonly": true },
      { "path": "/Users/me/outputs" }
    ]
  },
  "prod": {
    "mounts": [
      { "path": "/Volumes/Production/data", "readonly": true }
    ]
  }
}
```

📝 **Note:** Requires `jq` to be installed. If `jq` is missing or the config file is invalid, extra mounts and ports are skipped with a warning and the sandbox runs normally.

## 🐳 Per-Project Dockerfile

Place a `.claude-sandbox.Dockerfile` in your project root to customize the container with project-specific dependencies. The file is a standard Dockerfile that builds on top of the base image:

```dockerfile
FROM claude-sandbox

RUN apt-get update && apt-get install -y python3 python3-pip
RUN pip3 install pandas
```

When present, a per-project image is automatically built before each run. This lets you pre-install tools, libraries, or system packages that your project needs without modifying the shared base image.

## 🛠️ Commands

| Command | Purpose |
|---------|---------|
| `./claude-sandbox-dev.sh install` | Build image and install `claude-sandbox` script to `~/.claude-sandbox/bin/` |
| `./claude-sandbox-dev.sh build` | Rebuild the container image |
| `./claude-sandbox-dev.sh update` | Pull latest changes and rebuild |
| `./claude-sandbox-dev.sh uninstall` | Remove the container image |
| `./claude-sandbox-dev.sh kill` | Force stop any running containers |

## 🔍 How It Works

```mermaid
graph LR
    A[Your Project] -->|mount at same path| B[Container]
    B --> C[Claude Code]
    C -->|full autonomy| D[Execute Commands]
    D -->|changes| A
```

1. **`claude-sandbox-dev.sh install`** builds an OCI-compatible image and installs a standalone script to `~/.claude-sandbox/bin/`
2. Running `claude-sandbox` starts a container with your current directory mounted at its actual path
3. Claude Code runs with `--dangerously-skip-permissions` inside the isolated environment
4. All changes to the mounted directory are reflected in your project
5. Optional: `.claude-sandbox.json` adds extra mounts for data directories
6. Marketplace plugins from `~/.claude/plugins/marketplaces` are mounted read-only into the container

## 📁 Project Structure

```
claude-sandbox/
├── Dockerfile              # OCI-compatible image definition
├── .dockerignore           # Files excluded from build context
├── claude-sandbox-dev.sh   # Dev CLI (build/install/uninstall/kill/update)
├── scripts/
│   ├── claude-sandbox-template.sh  # Standalone script template
│   ├── git-readonly-wrapper.sh # Read-only git wrapper for container
│   └── install-claude-code.sh  # Claude Code installer
├── tests/
│   └── smoke-test.sh       # Basic smoke tests
├── .github/workflows/
│   └── ci.yml              # Shellcheck + build CI
├── SECURITY.md
├── CLAUDE.md
└── README.md
```

## ⚙️ Resource Limits

By default, containers are limited to 4 CPUs and 8 GB memory. Override via environment variables:

```bash
CPU_LIMIT=2 MEMORY_LIMIT=4g claude-sandbox
```

## 🔧 Troubleshooting

### Docker not running

If you see "daemon is not running", start Docker Desktop:

```bash
docker info  # Should show Docker daemon info
```

### "ETIMEDOUT" or "Unable to connect to Anthropic services"

This usually indicates network issues inside the container. Verify Docker has internet access:

```bash
claude-sandbox shell
# Inside container:
curl -I https://api.anthropic.com
```

### Permission denied / UID mismatch

The container user UID is set at build time to match your host user. If you see permission errors on mounted files, rebuild:

```bash
./claude-sandbox-dev.sh build  # Rebuilds with your current UID
```

### "Configuration file corrupted" on first run

The `.claude.json` file needs to be valid JSON. Reset it:

```bash
echo '{}' > ~/.claude-sandbox/.claude.json
```

### Login doesn't persist

Make sure both config paths are mounted. Check the generated script includes:
- `-v ~/.claude-sandbox/claude-config:/home/claude/.claude`
- `-v ~/.claude-sandbox/.claude.json:/home/claude/.claude.json`

### Per-project mounts not working

1. Verify `jq` is installed: `which jq` or `brew install jq`
2. Validate your config: `jq . .claude-sandbox.json`
3. Check paths are absolute (start with `/`)
4. Ensure mount paths exist on the host (see `mkdir -p` hint in warnings)

### Port conflicts

If a port is already in use on the host, you'll see a bind error. Change the host port in `.claude-sandbox.json` or stop the conflicting process:

```bash
lsof -i :3000  # Find what's using the port
```

### Docker not enough resources

If builds or runs fail with out-of-memory errors, increase Docker Desktop's resource allocation in **Settings > Resources**.

## 🔔 Notifications

For macOS desktop notifications when Claude is ready for input, install [claude-code-notify](https://github.com/tsilva/claude-code-notify) and enable sandbox support during its installation.

The notification bridge uses TCP (`host.docker.internal:19223`) to relay messages from the container to the host, where `terminal-notifier` displays them.

## 🔒 Security

See [SECURITY.md](SECURITY.md) for details on the isolation model, what is and isn't protected, and how to report vulnerabilities.

## 📄 License

MIT
