---
permalink: /
---

# AgentBox

**Sandboxed AI agent runtime — run Goose CLI under NVIDIA OpenShell
with network policy, filesystem isolation, and process governance.**

AgentBox wraps [Goose](https://github.com/block/goose) in an
[NVIDIA OpenShell](https://developer.nvidia.com/openshell) sandbox so
every agent action — shell commands, file edits, HTTP requests — is
confined by kernel-enforced policy. The agent cannot reach endpoints
you haven't declared, write to directories you haven't allowed, or
escalate privileges beyond what the sandbox permits.

## How It Works

```
Host                              OpenShell Sandbox
────────────────────────────────  ──────────────────────────────
~/.local/bin/goose  ──bind-ro──→  /usr/local/bin/goose
~/.config/goose     ──bind-ro──→  /sandbox/.config/goose
~/.agents           ──bind-ro──→  /sandbox/.agents
<project-dir>       ──bind-rw──→  /sandbox/project

goose-sandbox (@gs)               Supervisor (PID 1)
  └─ openshell sandbox create       ├── Landlock LSM (filesystem)
     openshell sandbox exec          ├── seccomp BPF (syscalls)
                                     ├── CONNECT proxy + OPA (network)
                                     └── Agent (UID 1000)
                                          └── goose run / session
```

The Goose binary, config, and AgentFS skills are **bind-mounted** from
the host — not baked into the container image. One image, always
current, no rebuild on Goose updates.

## Workshop

Follow these labs in order to set up and experience a sandboxed Goose
agent on Fedora.

### Prerequisites

| Requirement | Minimum | Check |
|-------------|---------|-------|
| Fedora | 44 | `cat /etc/fedora-release` |
| Podman | 5.0+ | `podman --version` |
| Goose CLI | 1.0+ | `goose --version` |
| Model provider | Any (LiteLLM, Skupper, direct) | Provider-specific health check |
| AgentFS | USER scope (`~/.agents/`) | `ls ~/.agents/skills/` |

### Lab 1 — Install OpenShell

OpenShell provides the sandbox runtime: a Gateway (control plane) and
Supervisor (data plane injected into each container).

```bash
# Load the fedora-openshell skill and run setup
# (requires sudo for RPM installation)
bash .agents/skills/fedora-openshell/scripts/setup.sh

# Start the gateway
bash .agents/skills/fedora-openshell/scripts/start.sh

# Verify: 14 checks covering CLI, service, mTLS, Podman driver
bash .agents/skills/fedora-openshell/scripts/verify.sh
```

**What you should see:** All 14 checks pass. The gateway is running as
a systemd user service and reachable via mTLS.

### Lab 2 — Build the Sandbox Environment

This lab builds the shim container image, configures the gateway for
bind mounts, and installs the `goose-sandbox` wrapper CLI.

```bash
# Step 1: Build the Fedora shim image (~350 MB, runtime deps only)
bash .agents/skills/goose-openshell/scripts/build.sh

# Step 2: Configure gateway for bind mounts and UID mapping
bash .agents/skills/goose-openshell/scripts/configure.sh

# Step 3: Install wrapper CLI, policy, and bash completion
bash .agents/skills/goose-openshell/scripts/setup.sh

# Step 4: Verify the full stack (S1–S10)
bash .agents/skills/goose-openshell/scripts/verify.sh
```

**What you should see:** S1–S10 all pass. A test sandbox is created,
Goose binary executes inside it, and LiteLLM is reachable through the
network policy.

### Lab 3 — Run a Sandboxed Agent

The `goose-sandbox` wrapper (alias: `gs`) mirrors the Goose CLI
while managing the OpenShell sandbox lifecycle transparently.

#### One-shot prompt

```bash
# Ephemeral sandbox — created, used, deleted automatically
goose-sandbox run --text "What is the capital of France?"

# Or with the gs alias
gs run --text "List all files in the current directory"
```

#### Named session

```bash
# Persistent sandbox — survives across multiple runs
gs run --name demo --text "Create a Python hello world script"

# Reuse the same sandbox for follow-up
gs run --name demo --text "Add error handling to the script"
```

#### Interactive session

```bash
# Full interactive terminal (PTY allocated)
gs session --name workshop

# Type prompts interactively, Ctrl+C to exit
```

### Lab 4 — Observe Policy Enforcement

The sandbox enforces three isolation layers. Test each one.

#### Network: deny-by-default

```bash
# Inside an interactive session, try reaching an undeclared endpoint:
#   curl https://example.com
# Expected: 403 Forbidden (blocked by OPA policy)

# Try reaching a declared endpoint:
#   curl http://host.containers.internal:4000/health
# Expected: 200 OK (allowed by network_policies.litellm)
```

#### Filesystem: Landlock LSM

```bash
# Inside an interactive session:
#   echo test > /etc/test-file
# Expected: Permission denied (Landlock read_only)

#   cat /root/.ssh/id_rsa
# Expected: Permission denied (path not in policy)

#   echo test > /sandbox/project/test-file
# Expected: Success (read_write path)
```

#### Process: non-root enforcement

```bash
# Inside an interactive session:
#   id
# Expected: uid=1000(sandbox) gid=1000(sandbox)
```

### Lab 5 — Manage Sessions

```bash
# List all sandboxes
gs list

# Resume an existing session (with conversation history)
gs session resume workshop

# Delete a sandbox (runs in background, ~45s to fully remove)
gs delete workshop

# Check status (gateway health + sandbox list)
gs status
```

### Lab 6 — Customize the Policy

The network policy declares which endpoints the agent can reach and
which binaries can reach them.

Edit `~/.config/openshell/goose-policy.yaml`:

```yaml
network_policies:
  my_api:
    name: My Custom API
    endpoints:
      - host: api.example.com
        port: 443
    binaries:
      - path: /usr/local/bin/goose
      - path: /usr/bin/curl
```

After editing, delete existing sandboxes and create new ones —
policy is applied at sandbox creation time.

## Reference

### Configuration Files

| File | Purpose |
|------|---------|
| `~/.config/openshell/goose-policy.yaml` | Sandbox policy (network, filesystem, process) |
| `~/.config/openshell/gateway.toml` | Gateway config (bind mounts, drivers) |
| `~/.config/openshell/gateway.env` | Gateway environment (UID mapping) |
| `~/.config/containers/containers.conf` | Podman config (`base_hosts_file`) |
| `/etc/hosts` | Dual-resolution for `host.containers.internal` |

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GOOSE_BIN` | `~/.local/bin/goose` | Goose binary path |
| `GOOSE_CONFIG` | `~/.config/goose` | Goose config directory |
| `AGENTFS_DIR` | `~/.agents` | AgentFS directory |
| `SHIM_IMAGE` | `localhost/goose-shim:latest` | Container image |
| `POLICY_FILE` | `~/.config/openshell/goose-policy.yaml` | Sandbox policy |
| `PROJECT_DIR` | Current directory | Project mount point |

### Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Sandbox exits with "iproute2 not found" | Missing package in image | Rebuild image: `bash .agents/skills/goose-openshell/scripts/build.sh` |
| 403 on all HTTP requests | Endpoint not in policy | Add to `network_policies` in policy.yaml |
| "Permission denied" on bind-mount write | UID mapping not configured | Run `scripts/configure.sh` |
| "permission.yaml lock" panic | Config dir read-only | Wrapper handles this; reinstall: `scripts/setup.sh` |
| Delete hangs | Normal — supervisor graceful shutdown | Runs in background; check via `gs list` |
| SQLite CANTOPEN error | Stale bind-mount config | Reinstall wrapper: `scripts/setup.sh` |

## Documentation

| Document | Description |
|----------|-------------|
| [Requirements](docs/requirements.md) | Problem statement, goals, constraints |
| [Design](docs/design.md) | Architecture decisions and trade-offs |
| [Implementation](docs/implementation.md) | Config reference, skill stack, policy details |
| [Test Report](docs/test-report.md) | UAT results, issues discovered, known limitations |

### Interactive Diagrams

| Diagram | Type | Description |
|---------|------|-------------|
| [Sandbox Architecture](docs/sandbox-architecture.html) | Architecture | Components, bind mounts, security boundaries, network path |
| [Sandbox Lifecycle](docs/sandbox-lifecycle.html) | Lifecycle | Sandbox state machine: create → run → idle → delete |
| [Network Egress](docs/sandbox-egress.html) | Sequence | Allowed vs. blocked request flow through CONNECT proxy and OPA |

## Project Structure

```
agentbox/
├── README.md                     ← This workshop guide
├── AGENTS.md                     ← AgentFS project entry point
├── docs/
│   ├── requirements.md           ← Problem + goals
│   ├── design.md                 ← Architecture decisions
│   ├── implementation.md         ← Config + skill reference
│   ├── test-report.md            ← Test results
│   ├── sandbox-architecture.html ← Interactive architecture diagram
│   ├── sandbox-lifecycle.html    ← Sandbox state machine diagram
│   └── sandbox-egress.html       ← Network egress sequence diagram
├── .agents/
│   ├── SOUL.md                   ← Agent identity
│   ├── skills/
│   │   ├── fedora-openshell/     ← OpenShell install/manage
│   │   └── goose-openshell/      ← Sandbox setup/wrapper
│   ├── memories/                 ← Agent memories
│   └── profiles/                 ← Agent profiles
└── _config.yml                   ← GitHub Pages (Cayman theme)
```

## License

See [LICENSE](LICENSE) for details.
