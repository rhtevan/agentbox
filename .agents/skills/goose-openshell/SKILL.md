---
name: goose-openshell
description: >
  setup goose sandbox, configure goose sandbox,
  build goose shim image, goose sandbox status,
  test goose sandbox, teardown goose sandbox
platforms: ['linux']
metadata:
  author: agentfs
  version: "1.4.1"
  tags: [goose, openshell, sandbox, podman, container, shim]
  related_skills: [fedora-openshell]
user-invocable: true
disable-model-invocation: false
writes-files: true
---

# Goose OpenShell Sandbox

Configure and manage sandboxed Goose CLI sessions under NVIDIA
OpenShell. Uses a Fedora shim image with runtime deps only — the
goose binary, config, and agentfs are bind-mounted from the host.

**Prerequisite:** OpenShell must be installed and running.
Run `load_skill(name: "fedora-openshell")` → `scripts/verify.sh`
to confirm.

## Signal Routing

| Signal | Action |
|--------|--------|
| `setup goose sandbox` | Run `scripts/setup.sh` |
| `build goose shim image` | Run `scripts/build.sh` |
| `configure goose sandbox` | Run `scripts/configure.sh` |
| `goose sandbox status` | Run `scripts/status.sh` |
| `test goose sandbox` | Run `scripts/verify.sh` |
| `teardown goose sandbox` | Run `scripts/teardown.sh` |

## Architecture

```
Host                          │ OpenShell Sandbox
──────────────────────────────┼──────────────────────────────
~/.local/bin/goose ──bind-ro──┤→ /usr/local/bin/goose
~/.config/goose    ──bind-ro──┤→ /sandbox/.config/goose
~/.agents          ──bind-ro──┤→ /sandbox/.agents
<project-dir>     ──bind-rw──┤→ /sandbox/project
                              │
goose-sandbox (@gs)           │  Supervisor (PID 1, UID 0)
  └─ openshell sandbox create │    ├─ Landlock LSM
     openshell sandbox exec   │    ├─ seccomp BPF
                              │    ├─ veth pair + CONNECT proxy
                              │    └─ Agent (UID 1000)
                              │         └─ goose run/session
```

## Workflow

### Step 1 — Setup (🔒 Privilege Gate for OpenShell install)

```bash
bash ./.agents/skills/goose-openshell/scripts/setup.sh
```

Checks prerequisites: OpenShell installed + running, goose binary
exists, shim image built, gateway config applied. Reports missing
items and how to fix each.

### Step 2 — Build shim image

```bash
bash ./.agents/skills/goose-openshell/scripts/build.sh
```

Builds `localhost/goose-shim:latest` from `./Containerfile`.

### Step 3 — Configure gateway

```bash
bash ./.agents/skills/goose-openshell/scripts/configure.sh
```

Applies `enable_bind_mounts = true` in `gateway.toml` and
`OPENSHELL_PODMAN_USERNS=keep-id:uid=1000,gid=1000` in
`gateway.env`. Restarts gateway.

### Step 4 — Verify

```bash
bash ./.agents/skills/goose-openshell/scripts/verify.sh
```

Runs S1–S10 specification checks.

### Step 5 — Use

```bash
# One-shot prompt (ephemeral sandbox)
goose-sandbox run --text "What is 2+2?"

# Named session (persistent sandbox)
goose-sandbox run --name my-session --text "Hello"

# Reuse existing sandbox
goose-sandbox run --name my-session --text "Follow up"

# List / delete / status
goose-sandbox list
goose-sandbox delete my-session
goose-sandbox status
```

## Installed Artifacts

| Artifact | Installed Location | Factory Source |
|----------|-------------------|---------------|
| `goose-sandbox` | `~/.local/bin/goose-sandbox` | `goose-sandbox` (this skill dir) |
| `goose-policy.yaml` | `~/.config/openshell/goose-policy.yaml` | `policy.yaml` (this skill dir) |
| Shim image | `localhost/goose-shim:latest` | `Containerfile` (this skill dir) |

## Gateway Configuration

| File | Setting |
|------|---------|
| `~/.config/openshell/gateway.toml` | `enable_bind_mounts = true` |
| `~/.config/openshell/gateway.env` | `OPENSHELL_PODMAN_USERNS=keep-id:uid=1000,gid=1000` |

## Specification

| ID | Capability |
|:--:|-----------|
| S1 | OpenShell gateway is running and authenticated |
| S2 | Shim image `localhost/goose-shim:latest` exists |
| S3 | `enable_bind_mounts = true` in gateway.toml |
| S4 | `OPENSHELL_PODMAN_USERNS` set in gateway.env |
| S5 | `goose-policy.yaml` installed at `~/.config/openshell/` |
| S6 | `goose-sandbox` installed and executable at `~/.local/bin/` |
| S7 | `Containerfile` exists in skill directory |
| S8 | Sandbox creates successfully with shim image |
| S9 | Goose binary executes inside sandbox (version check) |
| S10 | LiteLLM reachable from sandbox (HTTP 200) |

## Tests

| Test | Spec | Command | Expected |
|:----:|:----:|---------|----------|
| T1 | S1 | `verify.sh \| grep S1` | ✅ |
| T2 | S2 | `verify.sh \| grep S2` | ✅ |
| T3 | S3 | `verify.sh \| grep S3` | ✅ |
| T4 | S4 | `verify.sh \| grep S4` | ✅ |
| T5 | S5 | `verify.sh \| grep S5` | ✅ |
| T6 | S6 | `verify.sh \| grep S6` | ✅ |
| T7 | S7 | `verify.sh \| grep S7` | ✅ |
| T8 | S8–S10 | `verify.sh` | Exit 0, all pass |
| T9 | — | `goose-sandbox run --text "echo hi"` | Sandbox created, response received |
| T10 | — | `goose-sandbox list` | Shows sandbox |

## Error Handling

| Script | Idempotent | On Failure |
|--------|:----------:|------------|
| `setup.sh` | ✅ | Reports missing prerequisites |
| `build.sh` | ✅ | Podman build errors printed |
| `configure.sh` | ✅ | Gateway restart failure → check logs |
| `verify.sh` | ✅ (read-only) | Reports failing checks |
| `teardown.sh` | ✅ | Removes image + gateway config changes |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Sandbox exits with code 1 + "ip helper not found" | `iproute` not in image | Rebuild image |
| Sandbox exits + "OCI USER is required" | No `process.run_as_user` in policy | Add to policy.yaml |
| "Permission denied" on bind-mount write | Missing `OPENSHELL_PODMAN_USERNS` | Run `configure.sh` |
| "Permission denied (os error 13)" at startup | Non-existent path in Landlock `read_only` | Remove from policy.yaml |
| 403 from proxy on HTTP request | Endpoint not in `network_policies` | Add to policy.yaml |
| "permission.yaml lock" panic | Config dir mounted read-only | Wrapper copies config to writable path |
| Sandbox name "AlreadyExists" | Duplicate name | Delete or use different name |

## Gotchas

1. Config dir is mounted read-only — the wrapper copies essential
   files to `/sandbox/.local/config/goose/` for write access
2. `mcp-hermit` cache in config dir has special permissions —
   the wrapper's selective copy skips it (not needed in sandbox)
3. Sandbox names must be unique — the wrapper reuses existing ones
4. `scheduler` and `linuxmcpserver` extensions will not work inside
   the sandbox (no systemd, limited /proc visibility)
5. Landlock paths must exist in the image — listing non-existent
   paths causes "Permission denied" at sandbox startup

## Changelog

See [CHANGELOG.md](./CHANGELOG.md).
