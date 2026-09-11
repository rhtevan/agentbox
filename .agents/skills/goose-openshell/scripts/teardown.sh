#!/usr/bin/env bash
# teardown.sh — Remove goose sandbox configuration
set -euo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

GATEWAY_TOML="${HOME}/.config/openshell/gateway.toml"
GATEWAY_ENV="${HOME}/.config/openshell/gateway.env"

echo "=== Goose Sandbox Teardown ==="
echo ""

# 1. Delete all goose sandboxes
SANDBOXES=$(openshell sandbox list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | tail -n +2 | awk '{print $1}' | grep -v '^$')
if [ -n "$SANDBOXES" ]; then
  echo "Sandboxes to delete:"
  echo "$SANDBOXES" | sed 's/^/  /'
  if [ "$DRY_RUN" = false ]; then
    echo "$SANDBOXES" | while read -r name; do
      openshell sandbox delete "$name" 2>/dev/null || true
    done
    echo "✅ Sandboxes deleted"
  fi
else
  echo "No sandboxes to delete"
fi

echo ""

# 2. Remove installed artifacts
INSTALLED_BIN="${HOME}/.local/bin/goose-sandbox"
INSTALLED_POLICY="${HOME}/.config/openshell/goose-policy.yaml"
INSTALLED_COMP="${HOME}/.local/share/bash-completion/completions/goose-sandbox"
INSTALLED_COMP_GS="${HOME}/.local/share/bash-completion/completions/gs"
if [ -f "$INSTALLED_BIN" ] || [ -f "$INSTALLED_POLICY" ] || [ -f "$INSTALLED_COMP" ]; then
  echo "Installed artifacts to remove:"
  [ -f "$INSTALLED_BIN" ] && echo "  $INSTALLED_BIN"
  [ -f "$INSTALLED_POLICY" ] && echo "  $INSTALLED_POLICY"
  [ -f "$INSTALLED_COMP" ] && echo "  $INSTALLED_COMP"
  [ -L "$INSTALLED_COMP_GS" ] && echo "  $INSTALLED_COMP_GS"
  if [ "$DRY_RUN" = false ]; then
    rm -f "$INSTALLED_BIN" "$INSTALLED_POLICY" "$INSTALLED_COMP" "$INSTALLED_COMP_GS"
    # Remove 'gs' alias from .bashrc
    if grep -q "alias gs='goose-sandbox'" "${HOME}/.bashrc" 2>/dev/null; then
      sed -i '/# goose-sandbox alias/d;/alias gs=.goose-sandbox./d' "${HOME}/.bashrc"
      echo "✅ alias 'gs' removed from ~/.bashrc"
    fi
    echo "✅ Installed artifacts removed"
  fi
else
  echo "No installed artifacts to remove"
fi

echo ""

# 3. Remove shim image (renumbered)
if podman image exists localhost/goose-shim:latest 2>/dev/null; then
  echo "Image to remove: localhost/goose-shim:latest"
  if [ "$DRY_RUN" = false ]; then
    podman rmi localhost/goose-shim:latest 2>/dev/null || true
    echo "✅ Shim image removed"
  fi
else
  echo "No shim image to remove"
fi

echo ""

# 3. Remove gateway config changes
echo "Gateway config to revert:"
echo "  - Remove enable_bind_mounts from $GATEWAY_TOML"
echo "  - Remove OPENSHELL_PODMAN_USERNS from $GATEWAY_ENV"
if [ "$DRY_RUN" = false ]; then
  sed -i '/enable_bind_mounts/d' "$GATEWAY_TOML" 2>/dev/null || true
  sed -i '/\[openshell\.drivers\.podman\]/d' "$GATEWAY_TOML" 2>/dev/null || true
  sed -i '/OPENSHELL_PODMAN_USERNS/d' "$GATEWAY_ENV" 2>/dev/null || true
  # Remove empty gateway.env
  [ -f "$GATEWAY_ENV" ] && [ ! -s "$GATEWAY_ENV" ] && rm -f "$GATEWAY_ENV"
  systemctl --user restart openshell-gateway 2>/dev/null || true
  echo "✅ Gateway config reverted and restarted"
fi

echo ""
if [ "$DRY_RUN" = true ]; then
  echo "[DRY RUN] No changes made."
else
  echo "✅ Teardown complete"
fi
