#!/bin/bash
set -e

RUNTIME_CMD="PLACEHOLDER_RUNTIME_CMD"
IMAGE_NAME="PLACEHOLDER_IMAGE_NAME"
SCRIPT_NAME="PLACEHOLDER_FUNCTION_NAME"

mkdir -p ~/.claude-sandbox/claude-config
[ -s ~/.claude-sandbox/.claude.json ] || echo '{}' > ~/.claude-sandbox/.claude.json

entrypoint_args=()
extra_mounts=()
extra_ports=()
workdir="$(pwd)"
profile_name=""
cmd_args=()
first_cmd=""
skip_next=false
dry_run=false

# Extract flags, pass remaining args to Claude
for arg in "$@"; do
  if [ "$skip_next" = true ]; then
    profile_name="$arg"
    skip_next=false
  elif [ "$arg" = "--profile" ] || [ "$arg" = "-p" ]; then
    skip_next=true
  elif [ "$arg" = "--version" ]; then
    ver_file="/opt/claude-code/VERSION"
    if [ -f "$ver_file" ]; then
      echo "$SCRIPT_NAME $(cat "$ver_file" | tr -d '[:space:]')"
    else
      echo "$SCRIPT_NAME unknown"
    fi
    exit 0
  elif [ "$arg" = "--dry-run" ]; then
    dry_run=true
  else
    [ -z "$first_cmd" ] && first_cmd="$arg"
    cmd_args+=("$arg")
  fi
done

# Handle "shell" command
if [ "$first_cmd" = "shell" ]; then
  entrypoint_args=(--entrypoint /bin/bash)
  cmd_args=("${cmd_args[@]:1}")
fi

# Parse project config for extra mounts
if [ -f ".claude-sandbox.json" ]; then
  if ! command -v jq &>/dev/null; then
    echo "Warning: jq not installed, skipping .claude-sandbox.json config" >&2
    echo "Install with: brew install jq" >&2
  else
    jq_error=""
    if ! jq_error=$(jq -e 'type == "object"' .claude-sandbox.json 2>&1); then
      echo "Error: Invalid .claude-sandbox.json: $jq_error" >&2
      exit 1
    fi

    # Profile-based format - each root key is a profile name
    profile_count=$(jq 'keys | length' .claude-sandbox.json 2>/dev/null || echo 0)

    if [ -z "$profile_name" ] && [ "$profile_count" -gt 0 ]; then
      # Interactive profile selection
      mapfile -t profile_array < <(jq -r 'keys[]' .claude-sandbox.json)
      echo "Available profiles:" >&2
      select profile_name in "${profile_array[@]}"; do
        [ -n "$profile_name" ] && break
        echo "Invalid selection." >&2
      done </dev/tty
    fi

    # Validate selected profile exists
    if [ -n "$profile_name" ]; then
      if ! jq -e --arg p "$profile_name" 'has($p)' .claude-sandbox.json &>/dev/null; then
        echo "Error: Profile '$profile_name' not found" >&2
        echo "Available: $(jq -r 'keys | join(", ")' .claude-sandbox.json)" >&2
        exit 1
      fi

      # Extract mounts for profile
      while IFS= read -r mount_spec; do
        [ -z "$mount_spec" ] && continue
        mount_path="${mount_spec%%:*}"
        if [[ "$mount_spec" == *":"*":"* ]]; then
          echo "Warning: Skipping mount path containing ':': $mount_path" >&2
        elif [[ "$mount_path" =~ [[:cntrl:]] ]]; then
          echo "Warning: Skipping mount with invalid characters" >&2
        elif [ ! -e "$mount_path" ]; then
          echo "Warning: Mount path does not exist: $mount_path" >&2
          echo "  Hint: Create it with: mkdir -p $mount_path" >&2
        else
          extra_mounts+=(-v "$mount_spec")
        fi
      done < <(jq -r --arg p "$profile_name" '(.[($p)].mounts // [])[] | .path + ":" + .path + (if .readonly then ":ro" else "" end)' .claude-sandbox.json 2>/dev/null)

      # Check if profile opts out of git readonly
      git_readonly=$(jq -r --arg p "$profile_name" '.[($p)].git_readonly // true' .claude-sandbox.json 2>/dev/null)

      # Extract ports for profile
      while IFS= read -r port_spec; do
        [ -z "$port_spec" ] && continue
        host_port="${port_spec%%:*}"
        container_port="${port_spec##*:}"
        if ! [[ "$host_port" =~ ^[0-9]+$ ]] || ! [[ "$container_port" =~ ^[0-9]+$ ]]; then
          echo "Warning: Invalid port specification: $port_spec" >&2
        elif [ "$host_port" -lt 1 ] || [ "$host_port" -gt 65535 ] || [ "$container_port" -lt 1 ] || [ "$container_port" -gt 65535 ]; then
          echo "Warning: Port out of range (1-65535): $port_spec" >&2
        else
          extra_ports+=(-p "127.0.0.1:$port_spec")
        fi
      done < <(jq -r --arg p "$profile_name" '(.[($p)].ports // [])[] | (.host|tostring) + ":" + (.container|tostring)' .claude-sandbox.json 2>/dev/null)

      # Extract network mode for profile
      network_mode=$(jq -r --arg p "$profile_name" '.[($p)].network // "bridge"' .claude-sandbox.json 2>/dev/null)
    fi
  fi
fi

# Git write access: when git_readonly is false, bypass the read-only wrapper
# by mounting the real git binary over the wrapper symlink
if [ -z "${git_readonly:-}" ]; then
  git_readonly="true"
fi
if [ "$git_readonly" = "false" ]; then
  extra_mounts+=(-v /usr/bin/git.real:/usr/bin/git:ro)
fi

# Network mode (default: bridge)
network_args=()
if [ -n "${network_mode:-}" ] && [ "$network_mode" != "bridge" ]; then
  case "$network_mode" in
    bridge|none)
      network_args=(--network "$network_mode")
      ;;
    *)
      echo "Error: Unsupported network mode '$network_mode' (allowed: bridge, none)" >&2
      exit 1
      ;;
  esac
fi

# Resource limits (configurable via env vars)
resource_args=()
resource_args+=(--cpus "${CPU_LIMIT:-4}")
resource_args+=(--memory "${MEMORY_LIMIT:-8g}")
resource_args+=(--pids-limit "${PIDS_LIMIT:-256}")
resource_args+=(--ulimit nofile=1024:2048)
resource_args+=(--ulimit fsize=1073741824:1073741824)

# Build per-project image if .claude-sandbox.Dockerfile exists
run_image="$IMAGE_NAME"
if [ -f ".claude-sandbox.Dockerfile" ]; then
  run_image="${IMAGE_NAME}-project"
  echo "Building per-project image..." >&2
  "$RUNTIME_CMD" build -q -f .claude-sandbox.Dockerfile -t "$run_image" . >&2
fi

# Session timeout (default: 6h)
session_timeout="${SESSION_TIMEOUT:-6h}"

# Extract timeout from profile config if available
if [ -n "${profile_name:-}" ] && [ -f ".claude-sandbox.json" ] && command -v jq &>/dev/null; then
  profile_timeout=$(jq -r --arg p "$profile_name" '.[($p)].timeout // empty' .claude-sandbox.json 2>/dev/null)
  [ -n "$profile_timeout" ] && session_timeout="$profile_timeout"
fi

# Validate session timeout format
if ! [[ "$session_timeout" =~ ^[0-9]+[smhd]?$ ]]; then
  echo "Error: Invalid session timeout format '$session_timeout' (expected: number with optional s/m/h/d suffix)" >&2
  exit 1
fi

# Audit logging: use a named container instead of --rm
container_name="claude-sandbox-$(date +%s)-$$"
mkdir -p ~/.claude-sandbox/logs

# Build the full docker command as an array
docker_cmd=(
  "$RUNTIME_CMD" run -it
  --name "$container_name"
  --cap-drop=ALL
  --security-opt=no-new-privileges
  --read-only
  --tmpfs /tmp:rw,nosuid,size=512m
  --tmpfs /home/claude/.cache:rw,nosuid,size=256m
  --tmpfs /home/claude/.npm:rw,nosuid,size=128m
  --tmpfs /home/claude/.config:rw,nosuid,size=64m
  --tmpfs /home/claude/.local:rw,nosuid,size=256m
  "${resource_args[@]}"
  "${network_args[@]}"
  --workdir "$workdir"
  -v "$workdir:$workdir"
  -v ~/.claude-sandbox/claude-config:/home/claude/.claude
  -v ~/.claude-sandbox/.claude.json:/home/claude/.claude.json
  -v ~/.claude/plugins/marketplaces:/home/claude/.claude/plugins/marketplaces:ro
  "${extra_mounts[@]}"
  "${extra_ports[@]}"
  "${entrypoint_args[@]}"
  "$run_image" "${cmd_args[@]}"
)

if [ "$dry_run" = true ]; then
  printf '%q ' "${docker_cmd[@]}"
  echo
  exit 0
fi

cleanup() {
  "$RUNTIME_CMD" kill "$container_name" 2>/dev/null || true
  "$RUNTIME_CMD" rm "$container_name" 2>/dev/null || true
}
trap cleanup INT TERM

exit_code=0
timeout "$session_timeout" "${docker_cmd[@]}" || exit_code=$?

# Dump session logs
log_file=~/.claude-sandbox/logs/${container_name}.log
"$RUNTIME_CMD" logs "$container_name" > "$log_file" 2>&1 || true
"$RUNTIME_CMD" rm "$container_name" > /dev/null 2>&1 || true
echo "Session log: $log_file" >&2

trap - INT TERM
exit $exit_code
