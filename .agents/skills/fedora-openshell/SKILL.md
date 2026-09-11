---
name: fedora-openshell
description: >
  setup openshell, install openshell, start openshell,
  stop openshell, openshell status, check openshell,
  teardown openshell, uninstall openshell,
  upgrade openshell, update openshell
platforms: ['linux']
metadata:
  author: agentfs
  version: "1.0.0"
  tags: [openshell, nvidia, sandbox, fedora, podman, systemd]
  related_skills: [goose-openshell]
user-invocable: true
disable-model-invocation: false
writes-files: false
---

# Fedora OpenShell

Install, manage, and verify NVIDIA OpenShell Gateway on Fedora.
OpenShell provides a sandboxed runtime for autonomous AI agents
using Landlock LSM, seccomp, and network namespace isolation.
This skill manages the OpenShell CLI and Gateway daemon via RPM
packages and a systemd user service on Fedora workstations with
rootless Podman as the compute driver.

## Prerequisites

- Fedora 32+ (glibc ≥ 2.28)
- Podman 5.x with rootless networking
- cgroups v2 (`stat -fc %T /sys/fs/cgroup` → `cgroup2fs`)
- Podman user socket active (`systemctl --user status podman.socket`)
- Kernel Landlock LSM enabled (`cat /sys/kernel/security/lsm`)
- `curl` available
- `sudo` access for RPM install/remove (privilege gates)

## Signal Routing

| Signal | Action |
|--------|--------|
| `setup openshell` / `install openshell` | `scripts/setup.sh` |
| `upgrade openshell` / `update openshell` | `scripts/setup.sh --upgrade` |
| `start openshell` | `scripts/start.sh` |
| `stop openshell` | `scripts/stop.sh` |
| `openshell status` / `check openshell` | `scripts/status.sh` |
| `teardown openshell` / `uninstall openshell` | `scripts/teardown.sh` |

## Workflow

### Step 1 — Check Prerequisites

```bash
bash ./.agents/skills/fedora-openshell/scripts/verify.sh
```

If S6 (Podman socket) or S7 (Landlock) fail, fix those before
proceeding. All other checks may fail if OpenShell is not yet
installed.

### Step 2 — Install OpenShell (🔒 Privilege Gate)

```bash
bash ./.agents/skills/fedora-openshell/scripts/setup.sh
```

This script checks prerequisites and exits with code 3,
presenting the install command for the user to run manually:

```bash
curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh
```

The install script downloads two RPMs (`openshell`, `openshell-gateway`),
installs them via `sudo dnf install`, starts the gateway user service,
generates mTLS certificates, and registers the local gateway.

**Agent action:** Present the command to the user and wait for
confirmation. Then run `scripts/verify.sh` to confirm S1–S9.

To install a specific version:

```bash
OPENSHELL_VERSION=v0.0.116 bash ./.agents/skills/fedora-openshell/scripts/setup.sh
```

### Step 3 — Verify Installation

```bash
bash ./.agents/skills/fedora-openshell/scripts/verify.sh
```

All checks S1–S9 must pass.

### Step 4 — Enable Linger (optional)

To keep the gateway running after logout:

```bash
sudo loginctl enable-linger $USER
```

## Operations

### Start

```bash
bash ./.agents/skills/fedora-openshell/scripts/start.sh
```

### Stop

```bash
bash ./.agents/skills/fedora-openshell/scripts/stop.sh
```

### Status

```bash
bash ./.agents/skills/fedora-openshell/scripts/status.sh
```

### Upgrade (🔒 Privilege Gate)

```bash
bash ./.agents/skills/fedora-openshell/scripts/setup.sh --upgrade
```

Same privilege gate as install — presents the command for user
to run manually. For breaking upgrades from pre-v0.0.37:

```bash
OPENSHELL_ACK_BREAKING_UPGRADE=1 bash ./.agents/skills/fedora-openshell/scripts/setup.sh --upgrade
```

### Teardown (🔒 Privilege Gate)

```bash
bash ./.agents/skills/fedora-openshell/scripts/teardown.sh
```

Stops the service, then exits with code 3 presenting the
`sudo dnf remove` command. After user confirms RPM removal,
optionally clean user state:

```bash
bash ./.agents/skills/fedora-openshell/scripts/teardown.sh --clean-state
```

Dry run (show what would be removed without doing it):

```bash
bash ./.agents/skills/fedora-openshell/scripts/teardown.sh --dry-run
```

## Installed Artifacts

| Layer | Path | Content |
|-------|------|---------|
| System (RPM) | `/usr/bin/openshell` | CLI binary |
| | `/usr/bin/openshell-gateway` | Gateway daemon |
| | `/usr/lib/systemd/user/openshell-gateway.service` | systemd user unit |
| | `/usr/share/openshell-gateway/gateway.toml.default` | Default config template |
| User config | `~/.config/openshell/gateway.toml` | Active gateway config |
| | `~/.config/openshell/gateways/openshell/` | Gateway registration + mTLS |
| User state | `~/.local/state/openshell/tls/` | TLS + JWT signing keys |
| | `~/.local/state/openshell/gateway/openshell.db` | Gateway database |
| | `~/.local/state/openshell/gateway/credentials/` | Encrypted key material |

## Specification

| ID | Capability | Verifiable By |
|:--:|-----------|---------------|
| S1 | `openshell` CLI exists and returns a version | `verify.sh` S1a–S1b |
| S2 | `openshell-gateway` binary exists | `verify.sh` S2 |
| S3 | `openshell-gateway.service` loaded, active, enabled | `verify.sh` S3a–S3c |
| S4 | Gateway reachable and authenticated (mTLS) | `verify.sh` S4a–S4b |
| S5 | Compute driver set to `podman` in gateway.toml | `verify.sh` S5 |
| S6 | Podman user socket active | `verify.sh` S6 |
| S7 | Kernel Landlock LSM enabled | `verify.sh` S7 |
| S8 | User config and state directories exist | `verify.sh` S8a–S8b |
| S9 | mTLS bundle exists | `verify.sh` S9 |

## Tests

| Test | Spec | Command | Expected Result |
|:----:|:----:|---------|----------------|
| T1 | S1 | `verify.sh 2>&1 \| grep S1` | S1a–S1b ✅ |
| T2 | S2 | `verify.sh 2>&1 \| grep S2` | S2 ✅ |
| T3 | S3 | `verify.sh 2>&1 \| grep S3` | S3a–S3c ✅ |
| T4 | S4 | `verify.sh 2>&1 \| grep S4` | S4a–S4b ✅ |
| T5 | S5 | `verify.sh 2>&1 \| grep S5` | S5 ✅ |
| T6 | S6 | `verify.sh 2>&1 \| grep S6` | S6 ✅ |
| T7 | S7 | `verify.sh 2>&1 \| grep S7` | S7 ✅ |
| T8 | S1–S9 | `verify.sh` | Exit 0, all pass |
| T9 | — | `teardown.sh --dry-run` | Prints plan, exit 0 |
| T10 | S3 | `stop.sh` → `start.sh` → `verify.sh` | Service restarts, all pass |

## Error Handling

| Script | Idempotent | On Failure |
|--------|:----------:|------------|
| `setup.sh` | ✅ | Exit 3 (privilege gate) — present install command to user |
| `start.sh` | ✅ | Exit 1 — check `journalctl --user -u openshell-gateway` |
| `stop.sh` | ✅ | Exit 1 if service not found (informational) |
| `status.sh` | ✅ (read-only) | Never modifies state |
| `teardown.sh` | ✅ | Exit 3 (privilege gate) — present remove command to user |
| `verify.sh` | ✅ (read-only) | Never modifies state |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `openshell status` connection refused | Gateway not running | `scripts/start.sh` |
| S3 ❌ service not found | RPMs not installed | Run `scripts/setup.sh` |
| S5 ❌ compute driver not podman | gateway.toml missing or wrong | Check `~/.config/openshell/gateway.toml` |
| S6 ❌ podman socket inactive | Socket not enabled | `systemctl --user enable --now podman.socket` |
| S7 ❌ landlock not in LSM | Kernel too old or LSM disabled | Need kernel 5.13+ with Landlock enabled |
| Gateway stops after logout | Linger not enabled | `sudo loginctl enable-linger $USER` |
| Breaking upgrade warning | Pre-v0.0.37 install detected | Set `OPENSHELL_ACK_BREAKING_UPGRADE=1` |

## Gotchas

- Gateway auto-generates mTLS certs on first start — do not
  manually create `gateway.toml` before first run
- `openshell status` requires the gateway to be running — fails
  with connection error if stopped (not a bug)
- The install script downloads Fedora-version-specific RPMs
  (e.g., `fc44`) — correct behavior
- No version pinning — `setup.sh` pulls latest unless
  `OPENSHELL_VERSION` env var is set

## Changelog

> See [CHANGELOG.md](./CHANGELOG.md) for version history.
