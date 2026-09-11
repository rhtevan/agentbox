# Test Report

## Environment

| Component | Version |
|-----------|---------|
| Fedora | 44 |
| Podman | 5.x (rootless) |
| OpenShell | 0.3.x |
| Goose CLI | 1.50.0 |
| goose-sandbox | 1.4.1 |
| goose-shim image | localhost/goose-shim:latest |
| Date | 2026-09-10 / 2026-09-11 |

## Specification Checks (verify.sh)

| ID | Check | Result |
|:--:|-------|:------:|
| S1 | OpenShell gateway is running and authenticated | ✅ |
| S2 | Shim image exists | ✅ |
| S3 | `enable_bind_mounts = true` in gateway.toml | ✅ |
| S4 | `OPENSHELL_PODMAN_USERNS` set in gateway.env | ✅ |
| S5 | `goose-policy.yaml` installed | ✅ |
| S6 | `goose-sandbox` installed and executable | ✅ |
| S7 | `Containerfile` exists in skill directory | ✅ |
| S8 | Sandbox creates successfully | ✅ |
| S9 | Goose binary runs inside sandbox | ✅ |
| S10 | LiteLLM reachable from sandbox | ✅ |

## User Acceptance Tests

| Test | Description | Result | Notes |
|:----:|-------------|:------:|-------|
| T1 | One-shot run: `goose-sandbox run --text "What is 2+2?"` | ✅ | Sandbox created, response received, sandbox cleaned |
| T2 | Named run: `goose-sandbox run --name uat-t2 --text "Hello"` | ✅ | Sandbox persists after run |
| T3 | Named run reuse: `goose-sandbox run --name uat-t2 --text "Follow up"` | ✅ | Reuses existing sandbox |
| T4 | List: `goose-sandbox list` | ✅ | Shows sandbox names and phases |
| T5 | Delete: `goose-sandbox delete uat-t2` | ✅ | Backgrounded, returns immediately |
| T6 | Status: `goose-sandbox status` | ✅ | Shows gateway health + sandbox list |
| T7 | Interactive session: `goose-sandbox session --name uat-t7` | ✅ | PTY allocated, accepts input |
| T8 | Policy enforcement: network deny | ✅ | `curl https://example.com` → 403 |
| T9 | Session resume: `goose-sandbox session resume uat-t9` | ✅ | Previous messages visible with `--history` |

## Issues Discovered During Testing

| # | Symptom | Root Cause | Fix | Version |
|---|---------|-----------|-----|---------|
| 1 | Exit code 139 (SIGSEGV) on goose binary | SELinux blocking bind-mount execution | `:z` SELinux label on mount | v1.0.0 |
| 2 | "OCI USER is required" | Missing `process.run_as_user` in policy | Added field | v1.0.0 |
| 3 | "iproute2 not found" | Missing package in image | Added to Containerfile | v1.0.0 |
| 4 | "permission.yaml lock" panic | Config dir read-only | Copy to writable /tmp | v1.0.1 |
| 5 | ANSI colors break phase detection | Terminal escape codes in output | Strip with sed | v1.0.1 |
| 6 | `set -e` exits on `((PASS++))` | Bash arithmetic returns 1 when operand is 0 | Changed to `set -uo pipefail` + `\|\| true` | v1.0.1 |
| 7 | Interactive session can't accept input | Missing `--tty` on `sandbox exec` | Added TTY for session, no-TTY for run | v1.1.2 |
| 8 | "cannot find name for user ID 1000" | No passwd entry in image | Added `useradd` to Containerfile | v1.1.1 |
| 9 | Session resume wrong syntax | Used `goose session resume` (invalid) | Changed to `goose session --resume --name` | v1.1.3 |
| 10 | 45-second delete hang | OpenShell supervisor graceful shutdown | Backgrounded delete | v1.2.1 |
| 11 | SQLite WAL CANTOPEN (code 14) | mmap/shared memory across user namespace | Reverted to sandbox-local DB | v1.2.0 |
| 12 | Trailing comma in JSON breaks sandbox create | Array element removed, comma remained | Fixed JSON generation | v1.2.2 |
| 13 | host.containers.internal shadowed | Host /etc/hosts copied into container | `base_hosts_file = "none"` | v1.0.0 |

## Negative Tests (Policy Enforcement)

| Test | Layer | Action | Expected | Result |
|:----:|-------|--------|----------|:------:|
| N1 | Network | `curl https://example.com` inside sandbox | 403 Forbidden | ✅ |
| N2 | Network | `curl http://host.containers.internal:4000/health` | 200 OK (allowed) | ✅ |
| N3 | Filesystem | Write to `/etc/passwd` | Permission denied | ✅ |
| N4 | Filesystem | Write to `/sandbox/project/` | Success (read-write) | ✅ |
| N5 | Filesystem | Read `/root/.ssh/` | Permission denied | ✅ |
| N6 | Process | Agent runs as UID 1000 | `id -u` returns 1000 | ✅ |

## Known Limitations

| # | Limitation | Impact |
|---|-----------|--------|
| 1 | Session DB is sandbox-local | Sessions lost on sandbox delete |
| 2 | `scheduler` extension unavailable | No systemd in sandbox |
| 3 | `linuxmcpserver` unavailable | Limited /proc visibility |
| 4 | Delete takes ~45s in background | Sandbox listed until fully removed |
| 5 | Supervisor shutdown not configurable | Hardcoded in OpenShell |
