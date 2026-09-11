#!/usr/bin/env bash
# setup.sh — Install/update goose-sandbox and verify prerequisites
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_BIN="${HOME}/.local/bin/goose-sandbox"
INSTALL_POLICY="${HOME}/.config/openshell/goose-policy.yaml"

PASS=0; FAIL=0; INSTALLED=0
check() {
  if eval "$2" >/dev/null 2>&1; then
    echo "✅ $1"
    ((PASS++)) || true
  else
    echo "❌ $1"
    ((FAIL++)) || true
  fi
}

echo "=== Goose Sandbox Setup ==="
echo ""

# Prerequisites
echo "--- Prerequisites ---"
check "OpenShell CLI installed" "command -v openshell"
check "OpenShell gateway running" "systemctl --user is-active openshell-gateway"
check "Goose binary exists" "test -x \${HOME}/.local/bin/goose"
check "Goose config exists" "test -f \${HOME}/.config/goose/config.yaml"
check "Agentfs directory exists" "test -d \${HOME}/.agents"
check "Shim image built" "podman image exists localhost/goose-shim:latest"
check "enable_bind_mounts in gateway.toml" "grep -q 'enable_bind_mounts.*=.*true' \${HOME}/.config/openshell/gateway.toml"
check "USERNS in gateway.env" "grep -q 'OPENSHELL_PODMAN_USERNS' \${HOME}/.config/openshell/gateway.env"

echo ""
echo "--- Install/Update ---"

# Install goose-sandbox
if [ -f "${SKILL_DIR}/goose-sandbox" ]; then
  mkdir -p "$(dirname "$INSTALL_BIN")"
  if [ -f "$INSTALL_BIN" ]; then
    INSTALLED_SUM=$(md5sum "$INSTALL_BIN" 2>/dev/null | cut -d' ' -f1)
    FACTORY_SUM=$(md5sum "${SKILL_DIR}/goose-sandbox" | cut -d' ' -f1)
    if [ "$INSTALLED_SUM" = "$FACTORY_SUM" ]; then
      echo "✅ goose-sandbox is up to date at $INSTALL_BIN"
    else
      install -m 755 "${SKILL_DIR}/goose-sandbox" "$INSTALL_BIN"
      echo "🔧 goose-sandbox updated at $INSTALL_BIN"
      ((INSTALLED++)) || true
    fi
  else
    install -m 755 "${SKILL_DIR}/goose-sandbox" "$INSTALL_BIN"
    echo "🔧 goose-sandbox installed at $INSTALL_BIN"
    ((INSTALLED++)) || true
  fi
else
  echo "❌ Factory goose-sandbox not found at ${SKILL_DIR}/goose-sandbox"
  ((FAIL++)) || true
fi

# Install policy
if [ -f "${SKILL_DIR}/policy.yaml" ]; then
  mkdir -p "$(dirname "$INSTALL_POLICY")"
  if [ -f "$INSTALL_POLICY" ]; then
    INSTALLED_SUM=$(md5sum "$INSTALL_POLICY" 2>/dev/null | cut -d' ' -f1)
    FACTORY_SUM=$(md5sum "${SKILL_DIR}/policy.yaml" | cut -d' ' -f1)
    if [ "$INSTALLED_SUM" = "$FACTORY_SUM" ]; then
      echo "✅ goose-policy.yaml is up to date at $INSTALL_POLICY"
    else
      install -m 644 "${SKILL_DIR}/policy.yaml" "$INSTALL_POLICY"
      echo "🔧 goose-policy.yaml updated at $INSTALL_POLICY"
      ((INSTALLED++)) || true
    fi
  else
    install -m 644 "${SKILL_DIR}/policy.yaml" "$INSTALL_POLICY"
    echo "🔧 goose-policy.yaml installed at $INSTALL_POLICY"
    ((INSTALLED++)) || true
  fi
else
  echo "❌ Factory policy.yaml not found at ${SKILL_DIR}/policy.yaml"
  ((FAIL++)) || true
fi

# Install bash completion
COMP_DIR="${HOME}/.local/share/bash-completion/completions"
COMP_SRC="${SKILL_DIR}/scripts/goose-sandbox-completion.bash"
COMP_DST="${COMP_DIR}/goose-sandbox"
if [ -f "$COMP_SRC" ]; then
  mkdir -p "$COMP_DIR"
  if [ ! -f "$COMP_DST" ] || ! diff -q "$COMP_SRC" "$COMP_DST" >/dev/null 2>&1; then
    cp "$COMP_SRC" "$COMP_DST"
    echo "🔧 bash completion installed at ${COMP_DST}"
    ((INSTALLED++)) || true
  else
    echo "✅ bash completion is up to date"
  fi
  # Also symlink for 'gs' alias
  if [ ! -L "${COMP_DIR}/gs" ] || [ "$(readlink "${COMP_DIR}/gs")" != "$COMP_DST" ]; then
    ln -sf "$COMP_DST" "${COMP_DIR}/gs"
    echo "🔧 bash completion symlinked for 'gs' alias"
  fi
fi

# Install 'gs' alias in .bashrc
if ! grep -q "alias gs=" "${HOME}/.bashrc" 2>/dev/null; then
  echo "" >> "${HOME}/.bashrc"
  echo "# goose-sandbox alias" >> "${HOME}/.bashrc"
  echo "alias gs='goose-sandbox'" >> "${HOME}/.bashrc"
  echo "🔧 alias 'gs' added to ~/.bashrc (source ~/.bashrc to activate)"
  ((INSTALLED++)) || true
else
  echo "✅ alias 'gs' already in ~/.bashrc"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Prerequisites: ${PASS} passed, ${FAIL} failed"
echo "Installed/Updated: ${INSTALLED} file(s)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Fix missing items:"
  echo "  - OpenShell: load_skill(name: 'fedora-openshell') → setup"
  echo "  - Shim image: bash ${SKILL_DIR}/scripts/build.sh"
  echo "  - Gateway config: bash ${SKILL_DIR}/scripts/configure.sh"
  exit 1
fi
exit 0
