# Design

## Architecture Overview

AgentBox layers three isolation mechanisms between the AI agent and
the host system. Each layer is enforced by the Linux kernel or
OpenShell supervisor — none are advisory.

```
┌─────────────────────────────────────────────────────────┐
│ Host (Fedora 44)                                        │
│  goose-sandbox CLI  ──── OpenShell Gateway (gRPC)       │
│                            │                            │
│  ┌─────────────────────────┼──────────────────────────┐ │
│  │ Podman Container (bridge network)                  │ │
│  │  Supervisor (PID 1, UID 0)                         │ │
│  │    ├── Landlock LSM (filesystem)                   │ │
│  │    ├── seccomp BPF (syscalls)                      │ │
│  │    ├── veth0 10.200.0.1 ← CONNECT proxy ← OPA     │ │
│  │    │                                               │ │
│  │  ┌─┤── Nested Network Namespace ──────────────────┐│ │
│  │  │ │  veth1 10.200.0.2                            ││ │
│  │  │ │  Agent process (UID 1000)                    ││ │
│  │  │ │    └── goose run / session                   ││ │
│  │  │ │         HTTP_PROXY → veth0:port              ││ │
│  │  └─┤─────────────────────────────────────────────┘│ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### D1: Shim Image (BYOC without baking)

**Decision:** The container image contains only runtime dependencies
(bash, git, python3, curl, etc.). The Goose binary, config, and
AgentFS are bind-mounted from the host at runtime.

**Rationale:**
- Eliminates version drift between host and sandbox Goose
- No image rebuild when Goose updates
- No secrets baked into image layers
- Image is ~350 MB vs. ~500 MB with Goose baked in

**Trade-off:** Requires `enable_bind_mounts = true` in gateway config,
which is a security-relevant setting. Mitigated by Landlock policy
restricting which paths the agent can actually access.

### D2: Provider URL dual-resolution

**Decision:** All provider `base_url` values use
`host.containers.internal` instead of `localhost`.

**Rationale:**
- On the host: `/etc/hosts` maps `host.containers.internal` → `127.0.0.1`
- In containers: Podman injects `host.containers.internal` → `169.254.1.2`
- Same config file works in both contexts without modification

**Prerequisite:** `base_hosts_file = "none"` in `~/.config/containers/containers.conf`
to prevent the host's `/etc/hosts` entry from being copied into
containers and shadowing Podman's injection.

### D3: UID mapping with keep-id

**Decision:** `OPENSHELL_PODMAN_USERNS=keep-id:uid=1000,gid=1000`

**Rationale:** Default rootless Podman maps container UID 0 → host
user, making UID 1000 map to a subordinate UID that cannot write to
bind-mounted host directories. `keep-id` maps container UID 1000 →
host user, enabling write access to the project directory bind-mount.
The supervisor (UID 0 inside container) retains container-scoped
capabilities for namespace setup.

### D4: Config read/write split

**Decision:** Goose config directory is bind-mounted read-only. The
wrapper copies essential files to `/tmp/goose-config/` inside the
sandbox and sets `XDG_CONFIG_HOME=/tmp/goose-config`.

**Rationale:** Goose writes a `permission.yaml.lock` file on startup.
Mounting config as read-write would allow the sandboxed agent to
modify its own config (provider keys, extensions). The copy-to-tmp
approach allows the lock file write without exposing host config.

### D5: Sandbox-local session DB

**Decision:** Session database lives at `/tmp/goose-data/` inside the
sandbox, not shared with the host.

**Rationale:** SQLite WAL mode uses `mmap` and shared memory for
concurrent access. These mechanisms do not work across the Podman
user namespace boundary (`SQLITE_CANTOPEN` error code 14). Sharing
a single DB file via bind-mount causes database corruption or lock
failures.

**Trade-off:** Sessions are lost when a sandbox is deleted. Mitigated
by session resume (`--history` flag replays previous messages) and
named sandboxes that persist across multiple `goose-sandbox run`
invocations.

### D6: Unique sandbox names

**Decision:** Sandbox name = session name. The wrapper enforces
uniqueness by reusing existing sandboxes or deleting errored ones.

**Rationale:** OpenShell returns `AlreadyExists` on duplicate sandbox
names. Goose session names are not unique. Mapping 1:1 gives a
consistent lifecycle: create → use → delete.

### D7: Background delete

**Decision:** `goose-sandbox delete` runs the OpenShell delete
asynchronously and returns immediately.

**Rationale:** OpenShell supervisor has a hardcoded ~45-second graceful
shutdown timeout. Blocking the terminal for 45 seconds on every delete
is unacceptable for interactive use. The user can verify deletion via
`goose-sandbox list`.

### D8: Factory pattern for skill artifacts

**Decision:** The `goose-openshell` skill owns source artifacts
(goose-sandbox wrapper, policy.yaml, Containerfile). `setup.sh`
installs them to standard locations. The wrapper is callable from
any project directory.

**Rationale:** Skill-as-factory means one source of truth with
installable outputs. Updates flow through `setup.sh` with md5sum
change detection. No symlinks, no PATH manipulation beyond
`~/.local/bin/`.

## Security Boundaries

| Layer | Mechanism | Enforced By | Revocable? |
|-------|-----------|-------------|------------|
| Filesystem | Landlock LSM | Linux kernel | No — locked at sandbox creation, inherited by all children |
| Network | OPA/Rego policy via CONNECT proxy | OpenShell supervisor | No — proxy is sole egress path |
| Process | seccomp BPF + nested namespace | Linux kernel + supervisor | No |
| Identity | `/proc/{pid}/exe` matching | OpenShell policy engine | No — binary path is immutable for running process |

## Network Policy Model

Deny-by-default. Each allowed endpoint is declared with:
- **Host + port** — exact match
- **Binary path** — only named binaries can reach that endpoint
- **SSRF protection** — link-local (169.254.0.0/16) blocked by
  default, but exact hostname exemption for `host.containers.internal`

```yaml
network_policies:
  litellm:
    endpoints:
      - host: host.containers.internal
        port: 4000
    binaries:
      - path: /usr/local/bin/goose
```

## Component Inventory

| Component | Source | Installed At | Owner |
|-----------|--------|-------------|-------|
| OpenShell Gateway | NVIDIA RPM | `~/.local/bin/openshell` | `fedora-openshell` skill |
| OpenShell Supervisor | OCI volume image | Injected by gateway | NVIDIA |
| Goose Shim Image | `Containerfile` | `localhost/goose-shim:latest` | `goose-openshell` skill |
| `goose-sandbox` wrapper | `goose-sandbox` (skill dir) | `~/.local/bin/goose-sandbox` | `goose-openshell` skill |
| Sandbox policy | `policy.yaml` (skill dir) | `~/.config/openshell/goose-policy.yaml` | `goose-openshell` skill |
| Bash completion | `goose-sandbox-completion.bash` | `~/.local/share/bash-completion/completions/` | `goose-openshell` skill |
