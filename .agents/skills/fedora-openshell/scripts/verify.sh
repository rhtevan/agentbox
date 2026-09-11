#!/usr/bin/env bash
# verify.sh — Verify OpenShell installation and prerequisites
# Usage: bash verify.sh
# Exit codes: 0 = all checks pass, 1 = one or more checks failed
set -euo pipefail

PASS=0
FAIL=0

check() {
  local label="$1" status="$2"
  if [[ "$status" == "PASS" ]]; then
    echo "✅ $label"
    PASS=$((PASS + 1))
  else
    echo "❌ $label"
    FAIL=$((FAIL + 1))
  fi
}

# S1: openshell CLI
if command -v openshell &>/dev/null; then
  check "S1a: openshell CLI exists ($(command -v openshell))" "PASS"
else
  check "S1a: openshell CLI exists" "FAIL"
fi

if openshell --version &>/dev/null; then
  check "S1b: openshell version: $(openshell --version 2>&1)" "PASS"
else
  check "S1b: openshell returns version" "FAIL"
fi

# S2: openshell-gateway binary
if command -v openshell-gateway &>/dev/null; then
  check "S2: openshell-gateway binary exists ($(command -v openshell-gateway))" "PASS"
else
  check "S2: openshell-gateway binary exists" "FAIL"
fi

# S3: systemd user service
if systemctl --user cat openshell-gateway.service &>/dev/null; then
  check "S3a: openshell-gateway.service loaded" "PASS"
else
  check "S3a: openshell-gateway.service loaded" "FAIL"
fi

if systemctl --user is-active openshell-gateway &>/dev/null; then
  check "S3b: openshell-gateway.service active" "PASS"
else
  check "S3b: openshell-gateway.service active" "FAIL"
fi

if systemctl --user is-enabled openshell-gateway &>/dev/null; then
  check "S3c: openshell-gateway.service enabled" "PASS"
else
  check "S3c: openshell-gateway.service enabled" "FAIL"
fi

# S4: Gateway reachable and authenticated
if command -v openshell &>/dev/null; then
  STATUS_OUT=$(openshell status 2>&1 || true)
  if echo "$STATUS_OUT" | grep -q 'Connected'; then
    check "S4a: Gateway reachable (Connected)" "PASS"
  else
    check "S4a: Gateway reachable" "FAIL"
  fi

  if echo "$STATUS_OUT" | grep -q 'Authenticated'; then
    check "S4b: Gateway authenticated (mTLS)" "PASS"
  else
    check "S4b: Gateway authenticated" "FAIL"
  fi
else
  check "S4a: Gateway reachable (CLI not found)" "FAIL"
  check "S4b: Gateway authenticated (CLI not found)" "FAIL"
fi

# S5: Compute driver set to podman
GATEWAY_TOML="$HOME/.config/openshell/gateway.toml"
if [[ -f "$GATEWAY_TOML" ]] && grep -q 'podman' "$GATEWAY_TOML"; then
  check "S5: Compute driver includes podman" "PASS"
else
  check "S5: Compute driver includes podman" "FAIL"
fi

# S6: Podman user socket
if systemctl --user is-active podman.socket &>/dev/null; then
  check "S6: Podman user socket active" "PASS"
else
  check "S6: Podman user socket active" "FAIL"
fi

# S7: Kernel Landlock LSM
LSM_LIST=$(cat /sys/kernel/security/lsm 2>/dev/null || echo "")
if echo "$LSM_LIST" | grep -q 'landlock'; then
  check "S7: Kernel Landlock LSM enabled" "PASS"
else
  check "S7: Kernel Landlock LSM enabled" "FAIL"
fi

# S8: User directories
if [[ -d "$HOME/.config/openshell" ]]; then
  check "S8a: Config dir exists (~/.config/openshell/)" "PASS"
else
  check "S8a: Config dir exists (~/.config/openshell/)" "FAIL"
fi

if [[ -d "$HOME/.local/state/openshell" ]]; then
  check "S8b: State dir exists (~/.local/state/openshell/)" "PASS"
else
  check "S8b: State dir exists (~/.local/state/openshell/)" "FAIL"
fi

# S9: mTLS bundle
MTLS_DIR="$HOME/.config/openshell/gateways/openshell/mtls"
if [[ -f "$MTLS_DIR/ca.crt" && -f "$MTLS_DIR/tls.crt" && -f "$MTLS_DIR/tls.key" ]]; then
  check "S9: mTLS bundle exists (ca.crt, tls.crt, tls.key)" "PASS"
else
  check "S9: mTLS bundle exists" "FAIL"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
