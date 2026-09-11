#!/usr/bin/env bash
# status.sh — Show goose sandbox status
set -euo pipefail

echo "=== Shim Image ==="
if podman image exists localhost/goose-shim:latest 2>/dev/null; then
  podman images localhost/goose-shim:latest --format "{{.Repository}}:{{.Tag}}  {{.Size}}  Created: {{.CreatedSince}}"
else
  echo "Not built"
fi

echo ""
echo "=== Gateway Config ==="
grep 'enable_bind_mounts' "${HOME}/.config/openshell/gateway.toml" 2>/dev/null || echo "enable_bind_mounts: not set"
cat "${HOME}/.config/openshell/gateway.env" 2>/dev/null || echo "gateway.env: not found"

echo ""
echo "=== Active Sandboxes ==="
openshell sandbox list 2>&1

echo ""
echo "=== Gateway ==="
openshell status 2>&1
