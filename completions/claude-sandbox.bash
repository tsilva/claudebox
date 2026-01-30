_claude_sandbox() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local prev="${COMP_WORDS[COMP_CWORD-1]}"

  case "$prev" in
    --profile|-p)
      if [ -f ".claude-sandbox.json" ] && command -v jq &>/dev/null; then
        COMPREPLY=($(compgen -W "$(jq -r 'keys[]' .claude-sandbox.json 2>/dev/null)" -- "$cur"))
      fi
      return
      ;;
  esac

  if [[ "$cur" == -* ]]; then
    COMPREPLY=($(compgen -W "--profile -p --dry-run --version" -- "$cur"))
  else
    COMPREPLY=($(compgen -W "shell login" -- "$cur"))
  fi
}

complete -F _claude_sandbox claude-sandbox
