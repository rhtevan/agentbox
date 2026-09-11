#!/usr/bin/env bash
# start.sh — Start the OpenShell gateway user service
# Usage: bash start.sh
# Exit codes: 0 = success, 1 = failure
set -euo pipefail

if ! systemctl --user cat openshell-gateway.service &>/dev/null; then
  echo "❌ openshell-gateway.service not found. Is OpenShell installed?"
  exit 1
fi

if systemctl --user is-active openshell-gateway &>/dev/null; then
  echo "✅ openshell-gateway is already running"
  exit 0
fi

echo "Starting openshell-gateway..."
systemctl --user start openshell-gateway

sleep 1

if systemctl --user is-active openshell-gateway &>/dev/null; then
  echo "✅ openshell-gateway started"
else
  echo "❌ openshell-gateway failed to start"
  echo "   Check: journalctl --user -u openshell-gateway -n 20"
  exit 1
fi
