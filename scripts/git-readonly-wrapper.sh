#!/bin/bash
#
# git-readonly-wrapper.sh - Restricts git to read-only subcommands
#
# Installed as /usr/bin/git inside the container. The real git binary
# lives at /usr/bin/git.real. Only allows a curated set of read-only
# subcommands; all others are blocked with an error message.
#

# Abort on any error
set -e

# Path to the real git binary, renamed during image build
REAL_GIT="/usr/bin/git.real"

# Allowlisted read-only subcommands — these cannot modify the repository
READONLY_CMDS="status log diff show branch tag remote ls-files ls-tree cat-file rev-parse rev-list describe shortlog blame grep reflog stash version help"

# Extract the git subcommand by iterating over arguments and skipping
# global flags (e.g. -C <dir>) that take a value argument after them
subcmd=""
skip_next=false
for arg in "$@"; do
  # If the previous arg was a flag that takes a value, skip this arg
  if [ "$skip_next" = true ]; then
    skip_next=false
    continue
  fi
  case "$arg" in
    # These global flags consume the next argument as their value
    -C|-c|--git-dir|--work-tree|--namespace)
      skip_next=true
      ;;
    # Skip all other flags (single-token options like --bare, -v, etc.)
    -*)
      ;;
    # First non-flag argument is the subcommand
    *)
      subcmd="$arg"
      break
      ;;
  esac
done

# No subcommand (bare "git") — allow it; git just prints help text
if [ -z "$subcmd" ]; then
  exec "$REAL_GIT" "$@"
fi

# Check the subcommand against the read-only allowlist
for allowed in $READONLY_CMDS; do
  if [ "$subcmd" = "$allowed" ]; then
    # Special case: "stash" is only allowed with "list", "show", or no args
    # (other stash operations like pop/apply/drop modify the worktree)
    if [ "$subcmd" = "stash" ]; then
      for a in "$@"; do
        # Skip the "stash" token itself
        [ "$a" = "stash" ] && continue
        case "$a" in
          # Skip flags (e.g. --stat, --patch)
          -*) continue ;;
          # These stash sub-subcommands are read-only
          list|show) break ;;
          # Block all other stash operations (pop, apply, drop, push, etc.)
          *)
            echo "error: git stash $a is not allowed (read-only mode)" >&2
            echo "Allowed stash operations: list, show" >&2
            exit 1
            ;;
        esac
      done
    fi

    # Rebuild args stripping all -c key=value pairs to prevent config-based
    # code execution (e.g. core.pager, core.fsmonitor, alias.* can run
    # arbitrary commands via git config injection)
    safe_args=()
    skip_c=false
    for a in "$@"; do
      # If previous arg was -c, this arg is its key=value — skip it
      if [ "$skip_c" = true ]; then
        skip_c=false
        continue
      fi
      # Detect -c flag and mark the next arg for skipping
      if [ "$a" = "-c" ]; then
        skip_c=true
        continue
      fi
      # Keep all other arguments
      safe_args+=("$a")
    done

    # Execute the real git with sanitized arguments
    exec "$REAL_GIT" "${safe_args[@]}"
  fi
done

# Special case: "config" with read-only flags only
# git config without --get/--list would allow writing config values
if [ "$subcmd" = "config" ]; then
  for arg in "$@"; do
    case "$arg" in
      # These flags make git config read-only — allow the command
      --get|--get-all|--get-regexp|--list|-l)
        exec "$REAL_GIT" "$@"
        ;;
    esac
  done
  # No read-only flag found — block the write operation
  echo "error: git config (write) is not allowed (read-only mode)" >&2
  echo "Allowed: git config --get, --get-all, --get-regexp, --list" >&2
  exit 1
fi

# Subcommand not in allowlist — block it with a helpful error
echo "error: git $subcmd is not allowed (read-only mode)" >&2
echo "Allowed commands: $READONLY_CMDS, config --get/--list" >&2
exit 1
