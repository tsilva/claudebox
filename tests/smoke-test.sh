#!/bin/bash
#
# smoke-test.sh - Basic smoke tests for claude-sandbox
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

echo "=== claude-sandbox smoke tests ==="
echo ""

# Test 1: Shell scripts pass bash -n syntax check
echo "--- Syntax checks ---"
for script in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/claude-sandbox-dev.sh "$REPO_ROOT"/tests/*.sh; do
  name="$(basename "$script")"
  if bash -n "$script" 2>/dev/null; then
    pass "$name syntax OK"
  else
    fail "$name syntax error"
  fi
done

# Test 2: Docker image builds (only if Docker is available)
echo ""
echo "--- Docker build ---"
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  if docker build -t claude-sandbox-test "$REPO_ROOT" >/dev/null 2>&1; then
    pass "Docker image builds successfully"

    # Test 4: Claude binary is accessible in container
    echo ""
    echo "--- Container checks ---"
    if docker run --rm claude-sandbox-test --version >/dev/null 2>&1; then
      pass "Claude binary accessible in container"
    else
      fail "Claude binary not accessible in container"
    fi

    # Cleanup
    docker image rm claude-sandbox-test >/dev/null 2>&1 || true
  else
    fail "Docker image build failed"
  fi
else
  echo "  SKIP: Docker not available, skipping build tests"
fi

# Test 6: Template produces valid bash after placeholder substitution
echo ""
echo "--- Template validation ---"
template_content=$(sed -e 's|PLACEHOLDER_IMAGE_NAME|claude-sandbox|g' \
  -e 's|PLACEHOLDER_FUNCTION_NAME|claude-sandbox|g' \
  "$REPO_ROOT/scripts/claude-sandbox-template.sh")
if echo "$template_content" | bash -n 2>/dev/null; then
  pass "Template with substituted placeholders is valid bash"
else
  fail "Template has syntax errors after placeholder substitution"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
