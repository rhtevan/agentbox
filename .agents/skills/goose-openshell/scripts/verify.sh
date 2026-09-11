#!/usr/bin/env bash
# verify.sh — Verify goose-openshell specification S1–S10
set -uo pipefail

PASS=0; FAIL=0
check() {
  local id="$1" desc="$2"
  shift 2
  if "$@" >/dev/null 2>&1; then
    echo "✅ ${id}: ${desc}"
    ((PASS++)) || true
  else
    echo "❌ ${id}: ${desc}"
    ((FAIL++)) || true
  fi
}

GATEWAY_TOML="${HOME}/.config/openshell/gateway.toml"
GATEWAY_ENV="${HOME}/.config/openshell/gateway.env"

echo "=== Goose OpenShell Verification ==="
echo ""

# S1: Gateway running and authenticated
check "S1a" "Gateway service active" systemctl --user is-active openshell-gateway
check "S1b" "Gateway authenticated" bash -c 'openshell status 2>&1 | grep -q "Authenticated"'

# S2: Shim image exists
check "S2" "Shim image exists" podman image exists localhost/goose-shim:latest

# S3: enable_bind_mounts
check "S3" "enable_bind_mounts in gateway.toml" grep -q 'enable_bind_mounts.*=.*true' "$GATEWAY_TOML"

# S4: USERNS
check "S4" "OPENSHELL_PODMAN_USERNS in gateway.env" grep -q 'OPENSHELL_PODMAN_USERNS' "$GATEWAY_ENV"

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# S5: policy.yaml installed
check "S5" "goose-policy.yaml installed" test -f "${HOME}/.config/openshell/goose-policy.yaml"

# S6: goose-sandbox installed
check "S6" "goose-sandbox installed and executable" test -x "${HOME}/.local/bin/goose-sandbox"

# S7: Containerfile in skill dir
check "S7" "Containerfile exists in skill" test -f "${SKILL_DIR}/Containerfile"

# S8–S10: Live sandbox test
SANDBOX_NAME="verify-goose-$$"
echo ""
echo "🔲 Creating test sandbox '${SANDBOX_NAME}'..."

DRIVER_CONFIG="{\"podman\":{\"mounts\":[
  {\"type\":\"bind\",\"source\":\"${HOME}/.local/bin/goose\",\"target\":\"/usr/local/bin/goose\",\"read_only\":true,\"selinux_label\":\"shared\"},
  {\"type\":\"bind\",\"source\":\"${HOME}/.config/goose\",\"target\":\"/sandbox/.config/goose\",\"read_only\":true,\"selinux_label\":\"shared\"},
  {\"type\":\"bind\",\"source\":\"${HOME}/.local/share/goose\",\"target\":\"/sandbox/.local/share/goose\",\"read_only\":false,\"selinux_label\":\"shared\"},
  {\"type\":\"bind\",\"source\":\"${HOME}/.local/state/goose\",\"target\":\"/sandbox/.local/state/goose\",\"read_only\":false,\"selinux_label\":\"shared\"}
]}}"

openshell sandbox create \
  --name "$SANDBOX_NAME" \
  --from localhost/goose-shim:latest \
  --policy "${HOME}/.config/openshell/goose-policy.yaml" \
  --driver-config-json "$DRIVER_CONFIG" \
  -- sleep 120 >/dev/null 2>&1 &

# Wait for ready
READY=false
for i in $(seq 1 20); do
  sleep 1
  PHASE=$(openshell sandbox list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk -v n="$SANDBOX_NAME" '$1 == n { print $NF }')
  if [ "$PHASE" = "Ready" ]; then
    READY=true
    break
  fi
done

if [ "$READY" = true ]; then
  echo "✅ S8: Sandbox creates successfully"
  ((PASS++))

  # S9: goose binary
  if openshell sandbox exec --name "$SANDBOX_NAME" -- goose --version >/dev/null 2>&1; then
    echo "✅ S9: Goose binary executes inside sandbox"
    ((PASS++))
  else
    echo "❌ S9: Goose binary failed inside sandbox"
    ((FAIL++))
  fi

  # S10: LiteLLM reachable
  HTTP_CODE=$(openshell sandbox exec --name "$SANDBOX_NAME" -- \
    curl -s -o /dev/null -w "%{http_code}" http://host.containers.internal:4000/health/liveliness 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ S10: LiteLLM reachable from sandbox (HTTP 200)"
    ((PASS++))
  else
    echo "❌ S10: LiteLLM not reachable (HTTP ${HTTP_CODE})"
    ((FAIL++))
  fi
else
  echo "❌ S8: Sandbox failed to reach Ready"
  echo "❌ S9: Skipped (sandbox not ready)"
  echo "❌ S10: Skipped (sandbox not ready)"
  ((FAIL += 3))
fi

# Cleanup
openshell sandbox delete "$SANDBOX_NAME" >/dev/null 2>&1 || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ "$FAIL" -eq 0 ]
