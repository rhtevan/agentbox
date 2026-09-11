# Requirements

## Problem Statement

AI coding agents (Goose, Claude Code, Cursor, etc.) execute with the
full permissions of the host user. Every tool call — shell commands,
file edits, HTTP requests — runs unsandboxed. A single hallucinated
`rm -rf` or exfiltration curl can cause irrecoverable damage.

The agent runtime provides no process isolation, filesystem
confinement, or network governance. The user is the only control
plane, and the user is not watching every tool call.

## Goals

| # | Goal | Measurable Outcome |
|---|------|--------------------|
| G1 | **Filesystem isolation** | Agent cannot read/write outside declared paths; verified by Landlock LSM |
| G2 | **Network governance** | Agent can only reach declared endpoints; all other egress denied by OPA policy |
| G3 | **Process confinement** | Agent runs as non-root (UID 1000) inside a nested network namespace |
| G4 | **Transparent wrapper** | User experience mirrors native `goose` CLI; no new commands to learn |
| G5 | **No binary baking** | Goose binary is bind-mounted from host, not embedded in container image |
| G6 | **Session persistence** | Named sandboxes can be reused; sessions can be resumed with history |
| G7 | **Reproducible setup** | Entire stack installable via two AgentFS skills with idempotent scripts |

## Non-Goals

- Multi-user / multi-tenant isolation (single-user workstation only)
- GPU passthrough for local model inference
- Windows or macOS support (Landlock is Linux-only)
- Custom MCP server governance (subprocess identity via `/proc/{pid}/exe`
  is documented but not enforced by the wrapper)

## Constraints

| Constraint | Rationale |
|------------|-----------|
| Fedora 44+ | Landlock v4 support, Podman 5.x, systemd 256+ |
| Rootless Podman | No root daemon; UID mapping via `keep-id` |
| NVIDIA OpenShell 0.3.x | Current RPM release; API may change |
| Goose CLI binary | Requires max GLIBC 2.28 (any Fedora from 29+) |
| SQLite WAL limitation | Session DB cannot be shared over Podman bind-mounts; sandbox-local only |

## Stakeholders

| Role | Interest |
|------|----------|
| Agent operator (SRE, developer) | Reduce blast radius of autonomous agent actions |
| Security reviewer | Verify policy enforcement is kernel-backed, not advisory |
| Agent framework developer | Understand sandbox contract for extension compatibility |

## Assumptions

1. OpenShell Gateway runs as a systemd user service (not system-wide)
2. The host has a model provider reachable at a known endpoint
   (LiteLLM, Skupper, or direct)
3. Provider URLs use `host.containers.internal` for dual-resolution
   (host → 127.0.0.1, container → 169.254.1.2)
4. The user has `~/.agents/` (AgentFS USER scope) populated with
   skills and knowledge
