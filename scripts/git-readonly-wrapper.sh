#!/bin/bash
#
# git-readonly-wrapper.sh - Restricts git to read-only subcommands
#
# Installed as /usr/bin/git inside the container. The real git binary
# lives at /usr/bin/git.real. Only allows a curated set of read-only
# subcommands; all others are blocked with an error message.
#

set -e

REAL_GIT="/usr/bin/git.real"

# Allowlisted read-only subcommands
READONLY_CMDS="status log diff show branch tag remote ls-files ls-tree cat-file rev-parse rev-list describe shortlog blame grep reflog stash version help"

# Extract the git subcommand, skipping global flags and their arguments
subcmd=""
skip_next=false
for arg in "$@"; do
  if [ "$skip_next" = true ]; then
    skip_next=false
    continue
  fi
  case "$arg" in
    -C|-c|--git-dir|--work-tree|--namespace)
      skip_next=true
      ;;
    -*)
      # Skip other flags
      ;;
    *)
      subcmd="$arg"
      break
      ;;
  esac
done

# No subcommand (bare "git") — allow it (prints help)
if [ -z "$subcmd" ]; then
  exec "$REAL_GIT" "$@"
fi

# Check against allowlist
for allowed in $READONLY_CMDS; do
  if [ "$subcmd" = "$allowed" ]; then
    # Special case: "stash" is only allowed with "list" or no args
    if [ "$subcmd" = "stash" ]; then
      stash_action=""
      found_subcmd=false
      for a in "$@"; do
        if [ "$found_subcmd" = true ]; then
          case "$a" in
            -*) ;;
            *)
              stash_action="$a"
              break
              ;;
          esac
        fi
        [ "$a" = "stash" ] && found_subcmd=true
      done
      if [ -n "$stash_action" ] && [ "$stash_action" != "list" ] && [ "$stash_action" != "show" ]; then
        echo "error: git $subcmd $stash_action is not allowed (read-only mode)" >&2
        echo "Allowed stash operations: list, show" >&2
        exit 1
      fi
    fi
    # Special case: "config" only allowed for reads (--get, --get-all, --list, -l)
    if [ "$subcmd" = "config" ]; then
      # This won't match since config is not in the allowlist — handled below
      true
    fi
    exec "$REAL_GIT" "$@"
  fi
done

# Special case: "config" with read-only flags
if [ "$subcmd" = "config" ]; then
  for arg in "$@"; do
    case "$arg" in
      --get|--get-all|--get-regexp|--list|-l)
        exec "$REAL_GIT" "$@"
        ;;
    esac
  done
  echo "error: git config (write) is not allowed (read-only mode)" >&2
  echo "Allowed: git config --get, --get-all, --get-regexp, --list" >&2
  exit 1
fi

echo "error: git $subcmd is not allowed (read-only mode)" >&2
echo "Allowed commands: $READONLY_CMDS, config --get/--list" >&2
exit 1
