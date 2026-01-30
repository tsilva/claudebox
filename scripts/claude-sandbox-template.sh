#!/bin/bash
# =============================================================================
# claude-sandbox-template.sh - Standalone script template
#
# This template is processed by do_install() which replaces PLACEHOLDER_*
# tokens with real values. The resulting script is installed to
# ~/.claude-sandbox/bin/ and becomes the user-facing CLI.
# =============================================================================

# Abort on any error
set -eo pipefail

# Docker image name (replaced at install time by do_install)
IMAGE_NAME="PLACEHOLDER_IMAGE_NAME"
# CLI command name (replaced at install time by do_install)
SCRIPT_NAME="PLACEHOLDER_FUNCTION_NAME"

# Ensure the persistent config directory and session state file exist.
# claude-config is mounted into the container as ~/.claude/ for credentials.
mkdir -p ~/.claude-sandbox/claude-config
# Initialize .claude.json if missing or empty (Claude Code expects valid JSON)
[ -s ~/.claude-sandbox/.claude.json ] || echo '{}' > ~/.claude-sandbox/.claude.json

# --- Argument parsing ---
# Arrays and variables for building the docker run command
entrypoint_args=()     # Override entrypoint (used for "shell" command)
extra_mounts=()        # Additional -v mounts from profile config
extra_ports=()         # Additional -p ports from profile config
workdir="$(pwd)"       # Mount the current directory as the working directory
profile_name=""        # Selected profile from .claude-sandbox.json
cmd_args=()            # Arguments forwarded to Claude Code inside the container
first_cmd=""           # First non-flag argument (used to detect "shell" command)
skip_next=false        # Flag to skip the next argument (used for --profile value)
dry_run=false          # When true, print the docker command instead of running it
audit_log=false        # When true, keep named container and dump logs on exit

# Extract our flags (--profile, --dry-run), pass everything else to Claude
for arg in "$@"; do
  if [ "$skip_next" = true ]; then
    # This arg is the value for --profile/-p
    profile_name="$arg"
    skip_next=false
  elif [ "$arg" = "--profile" ] || [ "$arg" = "-p" ]; then
    # Next arg will be the profile name
    skip_next=true
  elif [ "$arg" = "--dry-run" ]; then
    # Enable dry-run mode: print command without executing
    dry_run=true
  else
    # Track the first non-flag arg to detect the "shell" command
    [ -z "$first_cmd" ] && first_cmd="$arg"
    cmd_args+=("$arg")
  fi
done

# Handle "shell" command: override entrypoint to bash for interactive inspection
if [ "$first_cmd" = "shell" ]; then
  entrypoint_args=(--entrypoint /bin/bash)
  # Remove "shell" from cmd_args so it isn't passed to bash
  cmd_args=("${cmd_args[@]:1}")
fi

# --- Per-project configuration (.claude-sandbox.json) ---
if [ -f ".claude-sandbox.json" ]; then
  # jq is required to parse the JSON config
  if ! command -v jq &>/dev/null; then
    echo "Warning: jq not installed, skipping .claude-sandbox.json config" >&2
    echo "Install with: brew install jq" >&2
  else
    # Validate the config file is a JSON object (not array, string, etc.)
    jq_error=""
    if ! jq_error=$(jq -e 'type == "object"' .claude-sandbox.json 2>&1); then
      echo "Error: Invalid .claude-sandbox.json: $jq_error" >&2
      exit 1
    fi

    # Count available profiles (root-level keys in the JSON object)
    profile_count=$(jq 'keys | length' .claude-sandbox.json 2>/dev/null || echo 0)

    # If no profile was specified via flag, prompt interactively
    if [ -z "$profile_name" ] && [ "$profile_count" -gt 0 ]; then
      # Read profile names into an array for the select menu
      mapfile -t profile_array < <(jq -r 'keys[]' .claude-sandbox.json)
      echo "Available profiles:" >&2
      # Present a numbered menu; reads from /dev/tty so it works in pipes
      select profile_name in "${profile_array[@]}"; do
        [ -n "$profile_name" ] && break
        echo "Invalid selection." >&2
      done </dev/tty
    fi

    # Validate the selected profile exists in the config
    if [ -n "$profile_name" ]; then
      if ! jq -e --arg p "$profile_name" 'has($p)' .claude-sandbox.json &>/dev/null; then
        echo "Error: Profile '$profile_name' not found" >&2
        echo "Available: $(jq -r 'keys | join(", ")' .claude-sandbox.json)" >&2
        exit 1
      fi

      # Extract all profile settings in a single jq call for efficiency.
      # Produces a normalized JSON object with mounts, ports, and scalar options.
      profile_config=$(jq -r --arg p "$profile_name" '
        .[($p)] | {
          mounts: [(.mounts // [])[] | .path + ":" + .path + (if .readonly then ":ro" else "" end)],
          ports: [(.ports // [])[] | (.host|tostring) + ":" + (.container|tostring)],
          network: (.network // "bridge"),
          audit_log: (.audit_log // false)
        }
      ' .claude-sandbox.json 2>/dev/null)

      # Parse mount specifications and validate each one
      while IFS= read -r mount_spec; do
        # Skip empty lines from jq output
        [ -z "$mount_spec" ] && continue
        # Extract the host path (everything before the first colon)
        mount_path="${mount_spec%%:*}"
        # Reject paths with multiple colons (ambiguous Docker mount syntax)
        if [[ "$mount_spec" == *":"*":"*":"* ]]; then
          echo "Warning: Skipping mount path containing ':': $mount_path" >&2
        # Reject paths with control characters (potential injection)
        elif [[ "$mount_path" =~ [[:cntrl:]] ]]; then
          echo "Warning: Skipping mount with invalid characters" >&2
        # Warn if the host path doesn't exist (Docker would create it as root)
        elif [ ! -e "$mount_path" ]; then
          echo "Warning: Mount path does not exist: $mount_path" >&2
          echo "  Hint: Create it with: mkdir -p $mount_path" >&2
        else
          # Valid mount — add to the docker run arguments
          extra_mounts+=(-v "$mount_spec")
        fi
      done < <(echo "$profile_config" | jq -r '.mounts[]')

      # Parse port specifications and validate ranges
      while IFS= read -r port_spec; do
        # Skip empty lines from jq output
        [ -z "$port_spec" ] && continue
        # Split host:container port pair
        host_port="${port_spec%%:*}"
        container_port="${port_spec##*:}"
        # Validate both ports are numeric
        if ! [[ "$host_port" =~ ^[0-9]+$ ]] || ! [[ "$container_port" =~ ^[0-9]+$ ]]; then
          echo "Warning: Invalid port specification: $port_spec" >&2
        # Validate ports are in the valid TCP/UDP range
        elif [ "$host_port" -lt 1 ] || [ "$host_port" -gt 65535 ] || [ "$container_port" -lt 1 ] || [ "$container_port" -gt 65535 ]; then
          echo "Warning: Port out of range (1-65535): $port_spec" >&2
        else
          # Bind to localhost only (127.0.0.1) to prevent external access
          extra_ports+=(-p "127.0.0.1:$port_spec")
        fi
      done < <(echo "$profile_config" | jq -r '.ports[]')

      # Parse scalar configuration values from the profile
      network_mode=$(echo "$profile_config" | jq -r '.network')
      audit_log=$(echo "$profile_config" | jq -r '.audit_log')
    fi
  fi
fi

# --- Git read-only .git mount ---
# When inside a git repo, mount .git as read-only to prevent commits.
# Without SSH keys or git credentials in the container, pushes fail anyway.
git_dir=""
if git -C "$workdir" rev-parse --git-dir &>/dev/null; then
  git_dir="$(cd "$workdir" && git rev-parse --absolute-git-dir)"
  extra_mounts+=(-v "$git_dir:$git_dir:ro")
else
  echo "⚠️  Warning: Not inside a git repository." >&2
  echo "   The working directory will be mounted read-write with no .git protection." >&2
  echo "   Claude will have full write access but cannot commit or push (no credentials)." >&2
  echo "   For git-based projects, run from the repo root for read-only .git protection." >&2
fi

# --- Network mode ---
# Default is "bridge" (normal Docker networking); "none" disables all networking
network_args=()
if [ -n "${network_mode:-}" ] && [ "$network_mode" != "bridge" ]; then
  case "$network_mode" in
    # Only bridge and none are allowed — host/macvlan/etc. would weaken isolation
    bridge|none)
      network_args=(--network "$network_mode")
      ;;
    *)
      echo "Error: Unsupported network mode '$network_mode' (allowed: bridge, none)" >&2
      exit 1
      ;;
  esac
fi

# --- Resource limits ---
# Prevent runaway processes from consuming all host resources.
# Defaults can be overridden via environment variables.
resource_args=()
resource_args+=(--cpus "${CPU_LIMIT:-4}")              # Max CPU cores
resource_args+=(--memory "${MEMORY_LIMIT:-8g}")        # Max memory
resource_args+=(--pids-limit "${PIDS_LIMIT:-256}")     # Max concurrent processes
resource_args+=(--ulimit nofile=1024:2048)             # Max open file descriptors
resource_args+=(--ulimit fsize=1073741824:1073741824)  # Max file size (1GB)

# --- Per-project Dockerfile ---
# If a project provides .claude-sandbox.Dockerfile, build a custom image
# layered on top of the base image for project-specific dependencies
run_image="$IMAGE_NAME"
if [ -f ".claude-sandbox.Dockerfile" ]; then
  run_image="${IMAGE_NAME}-project"
  echo "Building per-project image..." >&2
  # Build quietly (-q) since this runs on every invocation
  docker build -q -f .claude-sandbox.Dockerfile -t "$run_image" . >&2
fi

# --- Build the docker run command ---
# Use --rm for ephemeral containers; use named containers when audit logging
# is enabled so we can dump logs after the session ends.
container_args=()
if [ "$audit_log" = "true" ]; then
  # Name includes timestamp and PID for uniqueness across concurrent sessions
  container_name="claude-sandbox-$(date +%s)-$$"
  container_args+=(--name "$container_name")
  # Ensure the logs directory exists for session log dumps
  mkdir -p ~/.claude-sandbox/logs
else
  # Auto-remove container on exit for zero disk overhead
  container_args+=(--rm)
fi

# Assemble the complete docker run command as an array for safe quoting
docker_cmd=(
  docker run -it
  "${container_args[@]}"
  # Security hardening: drop all Linux capabilities
  --cap-drop=ALL
  # Prevent processes from gaining new privileges (e.g. via setuid binaries)
  --security-opt=no-new-privileges
  # Mount rootfs as read-only; writable dirs use tmpfs below
  --read-only
  # Tmpfs mounts for directories that need write access (size-limited)
  --tmpfs /tmp:rw,nosuid,size=512m
  --tmpfs /home/claude/.cache:rw,nosuid,size=256m
  --tmpfs /home/claude/.npm:rw,nosuid,size=128m
  --tmpfs /home/claude/.config:rw,nosuid,size=64m
  --tmpfs /home/claude/.local:rw,nosuid,size=256m,uid=1000,gid=1000
  # Apply CPU, memory, and process limits
  "${resource_args[@]}"
  # Apply network mode if non-default
  "${network_args[@]}"
  # Set the working directory inside the container to match the host
  --workdir "$workdir"
  # Mount the current project directory at the same path for path parity
  -v "$workdir:$workdir"
  # Persist Claude Code credentials and config across sessions
  -v ~/.claude-sandbox/claude-config:/home/claude/.claude
  # Persist Claude Code session state (conversation history, etc.)
  -v ~/.claude-sandbox/.claude.json:/home/claude/.claude.json
  # Mount marketplace plugins read-only so Claude can use installed plugins
  -v ~/.claude/plugins/marketplaces:/home/claude/.claude/plugins/marketplaces:ro
  # Add any profile-configured extra mounts, ports, and entrypoint overrides
  "${extra_mounts[@]}"
  "${extra_ports[@]}"
  "${entrypoint_args[@]}"
  # Image to run, followed by arguments forwarded to the entrypoint
  "$run_image" "${cmd_args[@]}"
)

# --- Dry run mode ---
# Print the full command for debugging instead of executing it
if [ "$dry_run" = true ]; then
  # Use printf %q for shell-safe quoting of each argument
  printf '%q ' "${docker_cmd[@]}"
  echo
  exit 0
fi

# --- Execute the container ---
if [ "$audit_log" = "true" ]; then
  # With audit logging: use a named container so we can dump logs afterward
  cleanup() {
    # On interrupt/termination, force-stop and remove the named container
    docker kill "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
  }
  # Register cleanup for SIGINT (Ctrl+C) and SIGTERM
  trap cleanup INT TERM

  # Run the container; capture the exit code
  exit_code=0
  "${docker_cmd[@]}" || exit_code=$?

  # Dump the container's stdout/stderr to a log file for audit review
  log_file=~/.claude-sandbox/logs/${container_name}.log
  docker logs "$container_name" > "$log_file" 2>&1 || true
  # Remove the named container now that logs are captured
  docker rm "$container_name" > /dev/null 2>&1 || true
  echo "Session log: $log_file" >&2

  # Remove the trap and exit with the container's exit code
  trap - INT TERM
  exit $exit_code
else
  # Without audit logging: simple ephemeral run
  exit_code=0
  "${docker_cmd[@]}" || exit_code=$?
  # Propagate the container's exit code
  exit $exit_code
fi
