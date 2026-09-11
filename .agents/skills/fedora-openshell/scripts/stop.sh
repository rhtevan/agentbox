#!/usr/bin/env bash
# stop.sh — Stop the OpenShell gateway user service
# Usage: bash stop.sh
# Exit codes: 0 = success, 1 = failure
set -euo pipefail

if ! systemctl --user cat openshell-gateway.service &>/dev/null; then
  echo "❌ openshell-gateway.service not found. Is OpenShell installed?"
  exit 1
fi

if ! systemctl --user is-active openshell-gateway &>/dev/null; then
  echo "✅ openshell-gateway is already stopped"
  exit 0
fi

echo "Stopping openshell-gateway..."
systemctl --user stop openshell-gateway

if ! systemctl --user is-active openshell-gateway &>/dev/null; then
  echo "✅ openshell-gateway stopped"
else
  echo "❌ openshell-gateway failed to stop"
  exit 1
fi
