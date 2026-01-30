#compdef claude-sandbox

_claude_sandbox() {
  local -a commands flags profiles

  flags=(
    '--profile[Use specific profile]:profile:->profiles'
    '-p[Use specific profile (short)]:profile:->profiles'
    '--dry-run[Print docker command without executing]'
    '--version[Print version]'
  )

  commands=(
    'shell:Drop into a bash shell inside the container'
    'login:Authenticate with Claude'
  )

  _arguments -s $flags '*:: :->args'

  case "$state" in
    profiles)
      if [ -f ".claude-sandbox.json" ] && command -v jq &>/dev/null; then
        profiles=(${(f)"$(jq -r 'keys[]' .claude-sandbox.json 2>/dev/null)"})
        _describe 'profile' profiles
      fi
      ;;
    args)
      _describe 'command' commands
      ;;
  esac
}

_claude_sandbox "$@"
