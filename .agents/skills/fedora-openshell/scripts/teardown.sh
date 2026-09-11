#!/usr/bin/env bash
# teardown.sh — Remove OpenShell from Fedora
# Usage: bash teardown.sh [--dry-run] [--clean-state]
# Exit codes: 0 = success/dry-run, 1 = failure, 2 = usage error, 3 = privilege gate
set -euo pipefail

DRY_RUN=false
CLEAN_STATE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)      DRY_RUN=true; shift ;;
    --clean-state)  CLEAN_STATE=true; shift ;;
    -h|--help)
      echo "Usage: bash teardown.sh [--dry-run] [--clean-state]"
      echo "  --dry-run      Show what would be removed"
      echo "  --clean-state  Also remove user config and state dirs"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

CONFIG_DIR="$HOME/.config/openshell"
STATE_DIR="$HOME/.local/state/openshell"
DATA_DIR="$HOME/.local/share/openshell"

if $DRY_RUN; then
  echo "=== Teardown Plan (dry run) ==="
  echo ""
  echo "1. Stop openshell-gateway.service"
  echo "2. Disable openshell-gateway.service"
  echo "3. Remove RPMs: sudo dnf remove openshell openshell-gateway"

  if $CLEAN_STATE; then
    echo "4. Remove user config: $CONFIG_DIR"
    echo "5. Remove user state:  $STATE_DIR"
    echo "6. Remove user data:   $DATA_DIR"
  else
    echo ""
    echo "User state preserved (use --clean-state to remove):"
    echo "  $CONFIG_DIR"
    echo "  $STATE_DIR"
    echo "  $DATA_DIR"
  fi

  echo ""
  echo "✅ Dry run complete — no changes made."
  exit 0
fi

# Stop and disable service
if systemctl --user is-active openshell-gateway &>/dev/null; then
  echo "Stopping openshell-gateway..."
  systemctl --user stop openshell-gateway
  echo "✅ Service stopped"
fi

if systemctl --user is-enabled openshell-gateway &>/dev/null; then
  echo "Disabling openshell-gateway..."
  systemctl --user disable openshell-gateway
  echo "✅ Service disabled"
fi

# Privilege gate for RPM removal
if rpm -q openshell &>/dev/null || rpm -q openshell-gateway &>/dev/null; then
  echo ""
  echo "🔒 Privilege gate: RPM removal requires sudo."
  echo "   Run manually in your terminal:"
  echo ""
  echo "     sudo dnf remove -y openshell openshell-gateway"
  echo ""
  echo "   Then confirm completion."
  exit 3
fi

echo "✅ RPMs already removed"

# Clean state (only reached if RPMs already gone or user re-runs after removal)
if $CLEAN_STATE; then
  for dir in "$CONFIG_DIR" "$STATE_DIR" "$DATA_DIR"; do
    if [[ -d "$dir" ]]; then
      echo "Removing $dir"
      rm -rf "$dir"
      echo "✅ Removed $dir"
    fi
  done
  echo "✅ User state cleaned"
else
  echo ""
  echo "User state preserved. Use --clean-state to remove:"
  echo "  $CONFIG_DIR"
  echo "  $STATE_DIR"
  echo "  $DATA_DIR"
fi
