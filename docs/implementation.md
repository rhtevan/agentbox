# Implementation

## Skill Stack

AgentBox is implemented as two AgentFS skills that compose a
sandboxed agent runtime.

| Skill | Version | Scope | Purpose |
|-------|---------|-------|---------|
| `fedora-openshell` | 1.0.0 | PROJECT | Install, manage, verify NVIDIA OpenShell on Fedora |
| `goose-openshell` | 1.4.1 | PROJECT | Build shim image, configure sandbox, install wrapper CLI |

### fedora-openshell

Manages the OpenShell Gateway lifecycle via RPM package management
and systemd user service control.

| Script | Purpose | Privilege |
|--------|---------|-----------|
| `setup.sh` | Install OpenShell RPM, initialize gateway | `sudo` required (exit 3 if missing) |
| `start.sh` | `systemctl --user start openshell-gateway` | User |
| `stop.sh` | `systemctl --user stop openshell-gateway` | User |
| `status.sh` | Service status + gateway health check | User |
| `verify.sh` | 14-point verification (CLI, service, config, mTLS) | User |
| `teardown.sh` | Remove RPM, clean config/state | `sudo` required |

### goose-openshell

Builds the sandbox environment and installs the `goose-sandbox`
wrapper CLI.

| Script | Purpose | Privilege |
|--------|---------|-----------|
| `setup.sh` | 8 prerequisite checks, install wrapper + policy + completion | User |
| `build.sh` | Build shim image, optional `--push` to OCI registry | User |
| `configure.sh` | Apply gateway.toml + gateway.env settings, restart | User |
| `verify.sh` | S1–S10 specification checks including live sandbox test | User |
| `status.sh` | Show sandbox list and gateway health | User |
| `teardown.sh` | Remove sandboxes, installed artifacts, shim image | User |

## Shim Image

```dockerfile
FROM registry.fedoraproject.org/fedora:44

RUN dnf install -y --setopt=install_weak_deps=False \
        bash git ripgrep curl python3 nodejs npm \
        iproute nftables procps-ng findutils sed gawk \
        diffutils libstdc++ \
    && dnf clean all

RUN curl -LsSf https://astral.sh/uv/install.sh \
    | env UV_INSTALL_DIR=/usr/local/bin sh

RUN useradd -u 1000 -m -d /sandbox -s /bin/bash sandbox \
    && chmod 755 /sandbox

WORKDIR /sandbox
```

**No ENTRYPOINT** — OpenShell overrides it with the supervisor.
**No USER directive** — the policy sets `process.run_as_user: "1000"`.

### Runtime Bind Mounts

| Host Path | Container Path | Mode |
|-----------|---------------|------|
| `~/.local/bin/goose` | `/usr/local/bin/goose` | read-only |
| `~/.config/goose/` | `/sandbox/.config/goose/` | read-only |
| `~/.agents/` | `/sandbox/.agents/` | read-only |
| `<project-dir>/` | `/sandbox/project/` | read-write |

## Sandbox Policy

```yaml
version: 1

process:
  run_as_user: "1000"
  run_as_group: "1000"

filesystem_policy:
  include_workdir: true
  read_only:  [/usr, /lib, /lib64, /proc, /dev/urandom, /etc, /bin, /sbin]
  read_write: [/sandbox, /tmp, /dev/null]

landlock:
  compatibility: best_effort

network_policies:
  litellm:
    endpoints: [{host: host.containers.internal, port: 4000}]
    binaries:  [{path: /usr/local/bin/goose}, {path: /usr/bin/curl}]
```

### Policy Enforcement Points

| Control | What It Blocks | Example |
|---------|---------------|---------|
| `filesystem_policy.read_only` | Write attempts to system dirs | `echo x > /etc/passwd` → Permission denied |
| `filesystem_policy.read_write` | Read/write outside declared paths | `cat /root/.ssh/id_rsa` → Permission denied |
| `network_policies` | Egress to undeclared endpoints | `curl https://evil.com` → 403 Forbidden |
| `process.run_as_user` | Running as root | UID 0 or 4294967295 → rejected at creation |
| `landlock.compatibility` | Bypass via child processes | All children inherit Landlock; `PR_SET_NO_NEW_PRIVS` |

## Host Configuration

### containers.conf

```ini
[containers]
base_hosts_file = "none"
```

Prevents host `/etc/hosts` from being copied into containers, which
would shadow Podman's `host.containers.internal → 169.254.1.2` injection.

### /etc/hosts

```
127.0.0.1    host.containers.internal
```

Enables the same `host.containers.internal` hostname to resolve
on the host (→ 127.0.0.1) and inside containers (→ 169.254.1.2).

### Gateway Configuration

| File | Key | Value | Purpose |
|------|-----|-------|---------|
| `gateway.toml` | `[openshell.drivers.podman] enable_bind_mounts` | `true` | Allow host bind mounts |
| `gateway.env` | `OPENSHELL_PODMAN_USERNS` | `keep-id:uid=1000,gid=1000` | Map container UID 1000 → host user |

## Wrapper CLI (`goose-sandbox`)

The wrapper translates `goose` CLI invocations into OpenShell sandbox
lifecycle operations:

| Wrapper Command | OpenShell Operations | Goose Command Inside |
|-----------------|---------------------|---------------------|
| `run --text "..."` | create → exec → delete | `goose run --text "..."` |
| `run --name X --text "..."` | create (if needed) → exec | `goose run --text "..."` |
| `session --name X` | create (if needed) → exec (--tty) | `goose session --name X` |
| `session resume X` | exec existing (--tty) | `goose session --resume --name X --history` |
| `delete X` | delete (backgrounded) | — |
| `list` | `openshell sandbox list` | — |

### Environment Inside Sandbox

```bash
HOME=/sandbox
XDG_CONFIG_HOME=/tmp/goose-config    # Writable copy of config
XDG_DATA_HOME=/tmp/goose-data        # Session DB (sandbox-local)
XDG_STATE_HOME=/tmp/goose-state      # Logs
HTTP_PROXY=http://10.200.0.1:<port>  # Set by supervisor
HTTPS_PROXY=http://10.200.0.1:<port> # Set by supervisor
```
