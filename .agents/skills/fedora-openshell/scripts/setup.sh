#!/usr/bin/env bash
# setup.sh — Install or upgrade OpenShell on Fedora
# Usage: bash setup.sh [--upgrade]
# Exit codes: 0 = already installed, 1 = failure, 2 = usage error, 3 = privilege gate
set -euo pipefail

MODE="install"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --upgrade) MODE="upgrade"; shift ;;
    -h|--help)
      echo "Usage: bash setup.sh [--upgrade]"
      echo "  --upgrade  Upgrade existing installation to latest"
      echo ""
      echo "Set OPENSHELL_VERSION=vX.Y.Z to pin a specific version."
      echo "Set OPENSHELL_ACK_BREAKING_UPGRADE=1 for pre-v0.0.37 upgrades."
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 2 ;;
  esac
done

# Prerequisite checks
PREREQ_FAIL=0

if ! command -v curl &>/dev/null; then
  echo "❌ curl is required but not found"
  PREREQ_FAIL=1
fi

if ! command -v podman &>/dev/null; then
  echo "❌ podman is required but not found"
  PREREQ_FAIL=1
fi

if ! systemctl --user is-active podman.socket &>/dev/null; then
  echo "❌ Podman user socket is not active"
  echo "   Fix: systemctl --user enable --now podman.socket"
  PREREQ_FAIL=1
fi

LSM_LIST=$(cat /sys/kernel/security/lsm 2>/dev/null || echo "")
if ! echo "$LSM_LIST" | grep -q 'landlock'; then
  echo "❌ Kernel Landlock LSM not enabled (need kernel 5.13+)"
  PREREQ_FAIL=1
fi

if [[ "$PREREQ_FAIL" -eq 1 ]]; then
  echo ""
  echo "Fix prerequisites above before installing OpenShell."
  exit 1
fi

echo "✅ Prerequisites met (curl, podman, podman.socket, landlock)"

# Check current installation
if command -v openshell &>/dev/null; then
  CURRENT=$(openshell --version 2>&1 || echo "unknown")
  if [[ "$MODE" == "install" ]]; then
    echo "✅ OpenShell already installed: $CURRENT"
    echo "   Use --upgrade to upgrade to latest."
    exit 0
  else
    echo "⚠️  Current version: $CURRENT — upgrading"
  fi
fi

# Build the install command
INSTALL_CMD="curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh"

if [[ -n "${OPENSHELL_VERSION:-}" ]]; then
  INSTALL_CMD="curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | OPENSHELL_VERSION=${OPENSHELL_VERSION} sh"
fi

if [[ -n "${OPENSHELL_ACK_BREAKING_UPGRADE:-}" ]]; then
  INSTALL_CMD="curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | OPENSHELL_ACK_BREAKING_UPGRADE=1 sh"
fi

echo ""
echo "🔒 Privilege gate: this operation requires sudo (dnf install)."
echo "   Run manually in your terminal:"
echo ""
echo "     $INSTALL_CMD"
echo ""
echo "   Then confirm completion so the agent can verify the installation."
exit 3
