#!/bin/bash
#
# smoke-test.sh - Basic smoke tests for claude-sandbox
#

# Abort on any error
set -euo pipefail

# Resolve the repo root from the script's own location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Counters for pass/fail tallies
PASS=0
FAIL=0

# Helper: record a passing test and increment counter
pass() { echo "  PASS: $1"; ((PASS++)); }
# Helper: record a failing test and increment counter
fail() { echo "  FAIL: $1"; ((FAIL++)); }

echo "=== claude-sandbox smoke tests ==="
echo ""

# --- Test 1: Shell scripts pass bash -n syntax check ---
# Validates every .sh file in the repo can be parsed without syntax errors
echo "--- Syntax checks ---"
for script in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/claude-sandbox-dev.sh "$REPO_ROOT"/tests/*.sh; do
  name="$(basename "$script")"
  # bash -n only parses without executing — catches syntax errors
  if bash -n "$script" 2>/dev/null; then
    pass "$name syntax OK"
  else
    fail "$name syntax error"
  fi
done

# --- Test 2: Docker image builds (only if Docker is available) ---
echo ""
echo "--- Docker build ---"
# Check both that the docker CLI exists and the daemon is running
if command -v docker &>/dev/null && docker info &>/dev/null; then
  # Build a test image tagged separately to avoid clobbering the real one
  if docker build -t claude-sandbox-test "$REPO_ROOT" &>/dev/null; then
    pass "Docker image builds successfully"

    # --- Test 3: Claude binary is accessible in container ---
    # Runs --version to verify the entrypoint and binary work end-to-end
    echo ""
    echo "--- Container checks ---"
    if docker run --rm claude-sandbox-test --version &>/dev/null; then
      pass "Claude binary accessible in container"
    else
      fail "Claude binary not accessible in container"
    fi

    # Cleanup: remove the test image to avoid leaving artifacts
    docker image rm claude-sandbox-test &>/dev/null || true
  else
    fail "Docker image build failed"
  fi
else
  echo "  SKIP: Docker not available, skipping build tests"
fi

# --- Test 4: Template produces valid bash after placeholder substitution ---
# Simulates what do_install() does: replace placeholders with real values
echo ""
echo "--- Template validation ---"
template_content=$(sed -e 's|PLACEHOLDER_IMAGE_NAME|claude-sandbox|g' \
  -e 's|PLACEHOLDER_FUNCTION_NAME|claude-sandbox|g' \
  "$REPO_ROOT/scripts/claude-sandbox-template.sh")
# Pipe the substituted template through bash -n to validate syntax
if echo "$template_content" | bash -n 2>/dev/null; then
  pass "Template with substituted placeholders is valid bash"
else
  fail "Template has syntax errors after placeholder substitution"
fi

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
# Exit non-zero if any test failed so CI catches it
[ "$FAIL" -eq 0 ] || exit 1
