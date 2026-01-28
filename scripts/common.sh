#!/bin/bash
#
# common.sh - Shared functions for claude-sandbox Docker and Apple Container scripts
#
# Required variables (must be set by wrapper scripts before sourcing):
#   RUNTIME_CMD      - Command to run (docker or container)
#   IMAGE_NAME       - Container image name
#   FUNCTION_NAME    - Shell function name
#   RUNTIME_NAME     - Human-readable runtime name
#   INSTALL_HINT     - Installation instructions for missing runtime
#   FUNCTION_COMMENT - Comment describing the shell function
#   REPO_ROOT        - Path to repository root
#

set -e

# Validate that all required configuration variables are set
validate_config() {
  local missing=()
  local required_vars=(RUNTIME_CMD IMAGE_NAME FUNCTION_NAME RUNTIME_NAME INSTALL_HINT FUNCTION_COMMENT REPO_ROOT)

  for var in "${required_vars[@]}"; do
    [ -z "${!var:-}" ] && missing+=("$var")
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    echo "Error: Missing required configuration variables: ${missing[*]}" >&2
    exit 1
  fi
}

# Check if the runtime CLI is available
check_runtime() {
  if ! command -v "$RUNTIME_CMD" &>/dev/null; then
    echo "Error: $RUNTIME_NAME is not installed or not in PATH"
    echo "$INSTALL_HINT"
    exit 1
  fi
}

# Detect shell config file (.zshrc or .bashrc)
# Sets SHELL_RC variable
detect_shell_rc() {
  if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
  elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
  else
    SHELL_RC="$HOME/.zshrc"
    echo "Warning: Neither .zshrc nor .bashrc found, creating $SHELL_RC"
    echo "If you use a different shell, add the function to your shell config manually."
  fi
}

# Generate the shell function definition
# Variables used: FUNCTION_COMMENT, FUNCTION_NAME, RUNTIME_CMD, IMAGE_NAME
generate_shell_function() {
  cat << FUNC_EOF
# ${FUNCTION_COMMENT}
${FUNCTION_NAME}() {
  mkdir -p ~/.claude-sandbox/claude-config
  [ -s ~/.claude-sandbox/.claude.json ] || echo '{}' > ~/.claude-sandbox/.claude.json

  local entrypoint_args=()
  local extra_mounts=()
  local extra_ports=()
  local workdir="\$(pwd)"
  local profile_name=""
  local cmd_args=()
  local first_cmd=""
  local skip_next=false

  # Extract --profile/-p flag, pass remaining args to Claude
  for arg in "\$@"; do
    if [ "\$skip_next" = true ]; then
      profile_name="\$arg"
      skip_next=false
    elif [ "\$arg" = "--profile" ] || [ "\$arg" = "-p" ]; then
      skip_next=true
    else
      [ -z "\$first_cmd" ] && first_cmd="\$arg"
      cmd_args+=("\$arg")
    fi
  done

  # Handle "shell" command (use first_cmd for zsh/bash compatibility)
  if [ "\$first_cmd" = "shell" ]; then
    entrypoint_args=(--entrypoint /bin/bash)
    cmd_args=("\${cmd_args[@]:1}")
  fi

  # Parse project config for extra mounts
  if [ -f ".claude-sandbox.json" ]; then
    if ! command -v jq &>/dev/null; then
      echo "Warning: jq not installed, skipping .claude-sandbox.json config" >&2
      echo "Install with: brew install jq" >&2
    elif ! jq -e 'type == "object"' .claude-sandbox.json &>/dev/null; then
      echo "Warning: Invalid .claude-sandbox.json format" >&2
    else
      local is_legacy
      is_legacy=\$(jq -e 'has("mounts") or has("ports")' .claude-sandbox.json 2>/dev/null && echo "yes" || echo "no")

      if [ "\$is_legacy" = "yes" ]; then
        # Legacy format - mounts at root level
        while IFS= read -r mount_spec; do
          [ -z "\$mount_spec" ] && continue
          local mount_path="\${mount_spec%%:*}"
          if [[ "\$mount_path" =~ [[:cntrl:]] ]]; then
            echo "Warning: Skipping mount with invalid characters" >&2
          elif [ ! -e "\$mount_path" ]; then
            echo "Warning: Mount path does not exist: \$mount_path" >&2
          else
            extra_mounts+=(-v "\$mount_spec")
          fi
        done < <(jq -r '(.mounts // [])[] | .path + ":" + .path + (if .readonly then ":ro" else "" end)' .claude-sandbox.json 2>/dev/null)

        # Extract ports for legacy format
        while IFS= read -r port_spec; do
          [ -z "\$port_spec" ] && continue
          local host_port="\${port_spec%%:*}"
          local container_port="\${port_spec##*:}"
          if ! [[ "\$host_port" =~ ^[0-9]+\$ ]] || ! [[ "\$container_port" =~ ^[0-9]+\$ ]]; then
            echo "Warning: Invalid port specification: \$port_spec" >&2
          elif [ "\$host_port" -lt 1 ] || [ "\$host_port" -gt 65535 ] || [ "\$container_port" -lt 1 ] || [ "\$container_port" -gt 65535 ]; then
            echo "Warning: Port out of range (1-65535): \$port_spec" >&2
          else
            extra_ports+=(-p "\$port_spec")
          fi
        done < <(jq -r '(.ports // [])[] | (.host|tostring) + ":" + (.container|tostring)' .claude-sandbox.json 2>/dev/null)
      else
        # Profile-based format - each root key is a profile name
        local profile_count
        profile_count=\$(jq 'keys | length' .claude-sandbox.json 2>/dev/null)

        if [ -z "\$profile_name" ]; then
          if [ "\$profile_count" -eq 1 ]; then
            # Single profile - auto-select
            profile_name=\$(jq -r 'keys[0]' .claude-sandbox.json)
            echo "Using profile: \$profile_name" >&2
          elif [ "\$profile_count" -gt 1 ]; then
            # Multiple profiles - interactive selection
            local profiles_list profile_array=()
            profiles_list=\$(jq -r 'keys[]' .claude-sandbox.json)
            while IFS= read -r p; do
              [ -n "\$p" ] && profile_array+=("\$p")
            done <<< "\$profiles_list"

            echo "Available profiles:" >&2
            local i=1
            for p in "\${profile_array[@]}"; do
              echo "  \$i) \$p" >&2
              ((i++))
            done

            while true; do
              printf "Select profile [1-\$profile_count]: " >&2
              read selection </dev/tty
              if [[ "\$selection" =~ ^[0-9]+\$ ]] && [ "\$selection" -ge 1 ] && [ "\$selection" -le "\$profile_count" ]; then
                # Find selected profile (portable across bash/zsh array indexing)
                local idx=1
                for p in "\${profile_array[@]}"; do
                  if [ "\$idx" -eq "\$selection" ]; then
                    profile_name="\$p"
                    break
                  fi
                  ((idx++))
                done
                break
              fi
              echo "Invalid selection." >&2
            done
          fi
        fi

        # Validate selected profile exists
        if [ -n "\$profile_name" ]; then
          if ! jq -e --arg p "\$profile_name" 'has(\$p)' .claude-sandbox.json &>/dev/null; then
            echo "Error: Profile '\$profile_name' not found" >&2
            echo "Available: \$(jq -r 'keys | join(", ")' .claude-sandbox.json)" >&2
            return 1
          fi

          # Extract mounts for profile
          while IFS= read -r mount_spec; do
            [ -z "\$mount_spec" ] && continue
            local mount_path="\${mount_spec%%:*}"
            if [[ "\$mount_path" =~ [[:cntrl:]] ]]; then
              echo "Warning: Skipping mount with invalid characters" >&2
            elif [ ! -e "\$mount_path" ]; then
              echo "Warning: Mount path does not exist: \$mount_path" >&2
            else
              extra_mounts+=(-v "\$mount_spec")
            fi
          done < <(jq -r --arg p "\$profile_name" '(.[\$p].mounts // [])[] | .path + ":" + .path + (if .readonly then ":ro" else "" end)' .claude-sandbox.json 2>/dev/null)

          # Extract ports for profile
          while IFS= read -r port_spec; do
            [ -z "\$port_spec" ] && continue
            local host_port="\${port_spec%%:*}"
            local container_port="\${port_spec##*:}"
            if ! [[ "\$host_port" =~ ^[0-9]+\$ ]] || ! [[ "\$container_port" =~ ^[0-9]+\$ ]]; then
              echo "Warning: Invalid port specification: \$port_spec" >&2
            elif [ "\$host_port" -lt 1 ] || [ "\$host_port" -gt 65535 ] || [ "\$container_port" -lt 1 ] || [ "\$container_port" -gt 65535 ]; then
              echo "Warning: Port out of range (1-65535): \$port_spec" >&2
            else
              extra_ports+=(-p "\$port_spec")
            fi
          done < <(jq -r --arg p "\$profile_name" '(.[\$p].ports // [])[] | (.host|tostring) + ":" + (.container|tostring)' .claude-sandbox.json 2>/dev/null)
        fi
      fi
    fi
  fi

  ${RUNTIME_CMD} run -it --rm \\
    --workdir "\$workdir" \\
    -v "\$workdir:\$workdir" \\
    -v ~/.claude-sandbox/claude-config:/home/claude/.claude \\
    -v ~/.claude-sandbox/.claude.json:/home/claude/.claude.json \\
    "\${extra_mounts[@]}" \\
    "\${extra_ports[@]}" \\
    "\${entrypoint_args[@]}" \\
    ${IMAGE_NAME} "\${cmd_args[@]}"
}
FUNC_EOF
}

# Build container image
do_build() {
  validate_config
  check_runtime

  echo "Building $IMAGE_NAME image..."
  "$RUNTIME_CMD" build --build-arg "CACHEBUST=$(date +%s)" -t "$IMAGE_NAME" "$REPO_ROOT"

  echo ""
  echo "Done! Image '$IMAGE_NAME' is ready."
  echo "Run '$FUNCTION_NAME' from any directory to start."
}

# Install shell function
do_install() {
  validate_config
  check_runtime

  # Build the image first
  do_build

  detect_shell_rc

  # Generate the shell function
  local shell_function
  shell_function=$(generate_shell_function)

  # Check if already installed (use precise pattern to avoid matching comments)
  if grep -q "^${FUNCTION_NAME}()[[:space:]]*{" "$SHELL_RC" 2>/dev/null; then
    echo "$FUNCTION_NAME function already exists in $SHELL_RC"
    echo "Please manually update the function or remove it and re-run install.sh"
  else
    echo "$shell_function" >> "$SHELL_RC"
    echo "Added $FUNCTION_NAME function to $SHELL_RC"
  fi

  echo ""
  echo "Installation complete!"
  echo ""
  echo "Run: source $SHELL_RC"
  echo ""
  echo "First-time setup (authenticate with Claude subscription):"
  echo "  $FUNCTION_NAME login"
  echo ""
  echo "Then from any project directory:"
  echo "  cd <your-project> && $FUNCTION_NAME"
  echo ""
  echo "To inspect the sandbox environment:"
  echo "  $FUNCTION_NAME shell"
}

# Uninstall image and shell function
do_uninstall() {
  validate_config

  # Prompt for confirmation
  read -p "This will remove the $IMAGE_NAME image and shell function. Continue? [y/N] " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
  fi

  check_runtime

  echo "Removing $IMAGE_NAME image..."
  "$RUNTIME_CMD" image rm "$IMAGE_NAME" 2>/dev/null || echo "Image not found, skipping"

  detect_shell_rc

  # Remove shell function from shell config
  if grep -q "^${FUNCTION_NAME}()" "$SHELL_RC" 2>/dev/null; then
    echo "Removing $FUNCTION_NAME function from $SHELL_RC..."
    # Remove the comment line preceding the function and the function itself
    sed -i.bak "/^# .*[Cc]laude [Ss]andbox/,/^}/d" "$SHELL_RC"
    rm -f "$SHELL_RC.bak"
    echo "Shell function removed."
  else
    echo "Shell function not found in $SHELL_RC, skipping"
  fi

  echo ""
  echo "Uninstall complete."
  echo ""
  echo "Run: source $SHELL_RC"
}

# Stop all running containers for this image
do_kill_containers() {
  validate_config
  check_runtime

  echo "Finding running $IMAGE_NAME containers..."

  local containers
  containers=$("$RUNTIME_CMD" ps -q --filter "ancestor=$IMAGE_NAME" 2>/dev/null)

  if [ -z "$containers" ]; then
    echo "No $IMAGE_NAME containers found running."
    return 0
  fi

  echo "Found containers:"
  for id in $containers; do
    echo "  - $id"
  done
  echo ""

  echo "Stopping containers..."
  for id in $containers; do
    "$RUNTIME_CMD" stop "$id" 2>/dev/null || "$RUNTIME_CMD" kill "$id" 2>/dev/null || true
  done

  echo ""
  echo "All $IMAGE_NAME containers stopped."
}
