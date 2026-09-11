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

## Test Procedures

### Prerequisites

Before running tests, complete Labs 1–2 from the [README](../README.md)
and verify the stack:

```bash
bash .agents/skills/goose-openshell/scripts/verify.sh
# All S1–S10 must pass
```

### T1 — One-shot ephemeral run

Run a single prompt in an ephemeral sandbox. The sandbox is created,
used, and deleted automatically.

```bash
goose-sandbox run --text "What is 2+2?"
```

**Expected:**
- Sandbox creates (you see `🔲 Creating sandbox...`)
- Goose responds with an answer containing "4"
- Sandbox is deleted after the run completes

**Verify cleanup:**

```bash
goose-sandbox list
# The ephemeral sandbox should not appear (or is deleting in background)
```

### T2 — Named run (persistent sandbox)

Run a prompt in a named sandbox that persists after the run.

```bash
goose-sandbox run --name uat-t2 --text "Hello, who are you?"
```

**Expected:**
- Sandbox `uat-t2` creates and remains after the run
- Goose responds with a greeting

**Verify persistence:**

```bash
goose-sandbox list
# uat-t2 should appear with phase "Running"
```

### T3 — Named run reuse

Send a follow-up prompt to the same named sandbox.

```bash
goose-sandbox run --name uat-t2 --text "What did I just ask you?"
```

**Expected:**
- No new sandbox creation message (reuses `uat-t2`)
- Goose responds (note: session DB is sandbox-local, so Goose
  may not recall the previous prompt — this tests sandbox reuse,
  not session continuity)

### T4 — List sandboxes

```bash
goose-sandbox list
```

**Expected:**
- Table output showing `uat-t2` with its phase
- If other sandboxes exist from previous tests, they appear too

### T5 — Delete sandbox

```bash
goose-sandbox delete uat-t2
```

**Expected:**
- Returns immediately (delete is backgrounded)
- Message indicates deletion is in progress

**Verify:**

```bash
# Wait a few seconds, then:
goose-sandbox list
# uat-t2 should eventually disappear (~45s for full removal)
```

### T6 — Status

```bash
goose-sandbox status
```

**Expected:**
- Gateway health check: reachable and authenticated
- Sandbox list (may be empty after T5 cleanup)

### T7 — Interactive session

Start an interactive terminal session.

```bash
goose-sandbox session --name uat-t7
```

**Expected:**
- Sandbox creates and terminal prompt appears
- You can type prompts interactively
- Agent responds to each prompt

**Test interaction:**

```
> What is the capital of Japan?
# Agent should respond with "Tokyo"
```

**Exit:** Press `Ctrl+C` to end the session.

**Cleanup:**

```bash
goose-sandbox delete uat-t7
```

### T8 — Policy enforcement (network, filesystem, process)

Create a sandbox and test each isolation layer.

```bash
goose-sandbox session --name uat-t8
```

**Network — blocked egress:**

```
> Run this command: curl -s -o /dev/null -w "%{http_code}" https://example.com
```

**Expected:** Agent reports `403` or a connection error (blocked by OPA).

**Network — allowed egress:**

```
> Run this command: curl -s -o /dev/null -w "%{http_code}" http://host.containers.internal:4000/health
```

**Expected:** Agent reports `200` (allowed by network policy).

**Filesystem — read-only enforcement:**

```
> Run this command: echo test > /etc/test-file
```

**Expected:** Agent reports `Permission denied` (Landlock read-only).

**Filesystem — write to allowed path:**

```
> Run this command: echo test > /sandbox/project/test-file && echo success
```

**Expected:** Agent reports `success` (read-write path).

**Process — non-root identity:**

```
> Run this command: id
```

**Expected:** Output shows `uid=1000(sandbox) gid=1000(sandbox)`.

**Exit and cleanup:**

```bash
# Ctrl+C to exit, then:
goose-sandbox delete uat-t8
```

### T9 — Session resume

Create a session, exit, and resume it.

**Step 1 — Create and interact:**

```bash
goose-sandbox session --name uat-t9
```

```
> Remember the word "pineapple". Just confirm you noted it.
# Agent confirms
```

Press `Ctrl+C` to exit.

**Step 2 — Resume:**

```bash
goose-sandbox session resume uat-t9
```

**Expected:**
- Previous conversation history is displayed (via `--history` flag)
- You can continue the conversation

```
> What word did I ask you to remember?
# Agent should recall "pineapple"
```

**Cleanup:**

```bash
goose-sandbox delete uat-t9
```

### N1 — Network: undeclared endpoint blocked

```bash
goose-sandbox run --name uat-n1 --text "Run: curl -s -o /dev/null -w '%{http_code}' https://example.com"
```

**Expected:** Output contains `403`.

**Cleanup:** `goose-sandbox delete uat-n1`

### N2 — Network: declared endpoint allowed

```bash
goose-sandbox run --name uat-n2 --text "Run: curl -s -o /dev/null -w '%{http_code}' http://host.containers.internal:4000/health"
```

**Expected:** Output contains `200`.

**Cleanup:** `goose-sandbox delete uat-n2`

### N3 — Filesystem: write to read-only path

```bash
goose-sandbox run --name uat-n3 --text "Run: echo test > /etc/test-file"
```

**Expected:** Output contains `Permission denied`.

**Cleanup:** `goose-sandbox delete uat-n3`

### N4 — Filesystem: write to allowed path

```bash
goose-sandbox run --name uat-n4 --text "Run: echo test > /sandbox/project/test-file && echo success"
```

**Expected:** Output contains `success`.

**Cleanup:** `goose-sandbox delete uat-n4`

### N5 — Filesystem: read outside allowed paths

```bash
goose-sandbox run --name uat-n5 --text "Run: cat /root/.ssh/id_rsa 2>&1"
```

**Expected:** Output contains `Permission denied` or `No such file or directory`.

**Cleanup:** `goose-sandbox delete uat-n5`

### N6 — Process: non-root identity

```bash
goose-sandbox run --name uat-n6 --text "Run: id -u"
```

**Expected:** Output contains `1000`.

**Cleanup:** `goose-sandbox delete uat-n6`

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
