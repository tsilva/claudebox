# Security

## Isolation Model

claude-sandbox runs Claude Code inside a Docker container with:

- `--cap-drop=ALL` — all Linux capabilities are dropped
- `--security-opt=no-new-privileges` — prevents privilege escalation
- Non-root user inside the container

### What IS isolated

- **Host filesystem**: Only explicitly mounted paths are accessible
- **Host processes**: Container cannot see or signal host processes
- **Privilege escalation**: Capabilities are dropped, no-new-privileges is set

### What is NOT isolated

- **Network access**: The container has unrestricted network access by default. Claude Code can make arbitrary HTTP requests, install packages, and communicate with external services.
- **Mounted directories**: Any mounted path (working directory, extra mounts) is fully writable unless mounted read-only.
- **Claude credentials**: Your Claude authentication tokens are mounted into the container.

## `--dangerously-skip-permissions`

Claude Code runs with `--dangerously-skip-permissions`, which means:

- All tool calls are auto-approved (file edits, command execution, etc.)
- Claude can execute arbitrary shell commands inside the container
- No human-in-the-loop confirmation for any action

This is the intended behavior — the container boundary provides the isolation layer instead of permission prompts.

## Git Safety

The `.git` directory is mounted read-only by default, preventing `git commit`, `git push`, and other write operations from inside the container. This can be disabled per-profile with `"git_readonly": false`.

## Recommendations

- Avoid mounting sensitive directories (SSH keys, credentials, etc.)
- Use read-only mounts where possible
- Review `.claude-sandbox.json` profiles before use
- Consider network isolation for sensitive workloads (future feature)

## Reporting Vulnerabilities

Please report security vulnerabilities by opening a GitHub issue at:
https://github.com/tsilva/claude-sandbox/issues

For sensitive issues, contact the maintainer directly via GitHub.
