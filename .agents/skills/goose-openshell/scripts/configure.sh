#!/usr/bin/env bash
# configure.sh — Apply OpenShell gateway config for goose sandbox
set -euo pipefail

GATEWAY_TOML="${HOME}/.config/openshell/gateway.toml"
GATEWAY_ENV="${HOME}/.config/openshell/gateway.env"

CHANGED=false

# 1. enable_bind_mounts
if ! grep -q 'enable_bind_mounts.*=.*true' "$GATEWAY_TOML" 2>/dev/null; then
  echo "🔲 Adding enable_bind_mounts to gateway.toml"
  if grep -q '\[openshell\.drivers\.podman\]' "$GATEWAY_TOML" 2>/dev/null; then
    # Section exists — append under it
    sed -i '/\[openshell\.drivers\.podman\]/a enable_bind_mounts = true' "$GATEWAY_TOML"
  else
    # Add section
    echo -e '\n[openshell.drivers.podman]\nenable_bind_mounts = true' >> "$GATEWAY_TOML"
  fi
  CHANGED=true
  echo "✅ enable_bind_mounts = true"
else
  echo "✅ enable_bind_mounts already set"
fi

# 2. OPENSHELL_PODMAN_USERNS
if ! grep -q 'OPENSHELL_PODMAN_USERNS' "$GATEWAY_ENV" 2>/dev/null; then
  echo "🔲 Setting OPENSHELL_PODMAN_USERNS in gateway.env"
  echo 'OPENSHELL_PODMAN_USERNS=keep-id:uid=1000,gid=1000' >> "$GATEWAY_ENV"
  CHANGED=true
  echo "✅ OPENSHELL_PODMAN_USERNS=keep-id:uid=1000,gid=1000"
else
  echo "✅ OPENSHELL_PODMAN_USERNS already set"
fi

# 3. Restart gateway if changed
if [ "$CHANGED" = true ]; then
  echo "🔲 Restarting openshell-gateway..."
  systemctl --user restart openshell-gateway
  sleep 2
  if systemctl --user is-active openshell-gateway >/dev/null 2>&1; then
    echo "✅ Gateway restarted"
  else
    echo "❌ Gateway failed to restart"
    journalctl --user -u openshell-gateway --no-pager -n 10
    exit 1
  fi
else
  echo "✅ No changes needed — gateway config is current"
fi
