#!/usr/bin/env bash
# status.sh — Show OpenShell gateway status and prerequisites
# Usage: bash status.sh
# Exit codes: 0 = healthy, 1 = issues found
set -euo pipefail

ISSUES=0

echo "=== OpenShell Status ==="
echo ""

# RPMs
if rpm -q openshell &>/dev/null; then
  echo "✅ RPM: $(rpm -q openshell)"
else
  echo "❌ RPM: openshell not installed"
  ISSUES=1
fi

if rpm -q openshell-gateway &>/dev/null; then
  echo "✅ RPM: $(rpm -q openshell-gateway)"
else
  echo "❌ RPM: openshell-gateway not installed"
  ISSUES=1
fi

# Service
echo ""
if systemctl --user is-active openshell-gateway &>/dev/null; then
  echo "✅ Service: active"
else
  echo "❌ Service: inactive"
  ISSUES=1
fi

# Gateway connectivity
echo ""
if command -v openshell &>/dev/null; then
  openshell status 2>&1 | sed 's/^/   /'
else
  echo "❌ openshell CLI not available"
  ISSUES=1
fi

# Prerequisites
echo ""
echo "=== Prerequisites ==="

if systemctl --user is-active podman.socket &>/dev/null; then
  echo "✅ Podman socket: active"
else
  echo "❌ Podman socket: inactive"
  ISSUES=1
fi

echo "✅ Podman: $(podman --version 2>/dev/null || echo 'not found')"
echo "✅ Kernel: $(uname -r)"

LSM_LIST=$(cat /sys/kernel/security/lsm 2>/dev/null || echo "unknown")
if echo "$LSM_LIST" | grep -q 'landlock'; then
  echo "✅ Landlock: enabled"
else
  echo "❌ Landlock: not found in LSM list"
  ISSUES=1
fi

echo ""
[[ "$ISSUES" -eq 0 ]] && echo "✅ All healthy" || echo "⚠️  $ISSUES issue(s) found"
[[ "$ISSUES" -eq 0 ]] && exit 0 || exit 1
