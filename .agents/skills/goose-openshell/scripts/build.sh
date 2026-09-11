#!/usr/bin/env bash
# build.sh — Build the Fedora Goose shim container image
#
# Usage:
#   build.sh                              Build locally
#   build.sh --push quay.io/user/img:tag  Build and push to registry
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTAINERFILE="${SKILL_DIR}/Containerfile"
IMAGE_NAME="localhost/goose-shim:latest"
PUSH_TARGET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push) PUSH_TARGET="$2"; shift 2 ;;
    *)      echo "Usage: build.sh [--push registry/image:tag]"; exit 2 ;;
  esac
done

if [ ! -f "$CONTAINERFILE" ]; then
  echo "❌ Containerfile not found at: $CONTAINERFILE"
  exit 1
fi

echo "🔲 Building shim image: $IMAGE_NAME"
podman build -t "$IMAGE_NAME" -f "$CONTAINERFILE" "$SKILL_DIR"

echo ""
echo "✅ Image built: $IMAGE_NAME"
podman images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}  {{.Size}}  {{.ID}}"

if [ -n "$PUSH_TARGET" ]; then
  echo ""
  echo "🔲 Tagging and pushing: $PUSH_TARGET"
  podman tag "$IMAGE_NAME" "$PUSH_TARGET"
  podman push "$PUSH_TARGET"
  echo "✅ Pushed: $PUSH_TARGET"
fi
