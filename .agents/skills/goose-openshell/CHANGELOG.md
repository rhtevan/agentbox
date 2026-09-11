# goose-openshell Changelog

| Updated | Change |
|---------|--------|
| 2026-09-11 08:45 | v1.4.1 — Reverted default SHIM_IMAGE to localhost/goose-shim:latest — eliminates disconnect between build.sh (local) and wrapper (remote). Push to registry remains opt-in via build.sh --push. |
| 2026-09-11 08:40 | v1.4.0 — Changed default SHIM_IMAGE from localhost/goose-shim:latest to quay.io/rhtevan/agentbox-goose-shim:latest. All scripts updated. Works without local build — pulls from registry on first run. |
| 2026-09-10 23:10 | v1.3.0 — Added bash completion for goose-sandbox and gs alias. Setup installs completion to ~/.local/share/bash-completion/completions/ and adds 'gs' alias to ~/.bashrc. Teardown removes both. Session resume now shows conversation history (--history flag). |
| 2026-09-10 23:06 | v1.2.3 — Added --history flag to session resume — shows previous messages when reconnecting to a sandbox session. |
| 2026-09-10 23:01 | v1.2.2 — Fixed trailing comma in driver-config-json that caused sandbox creation to fail silently. |
| 2026-09-10 22:53 | v1.2.1 — Background delete: sandbox delete runs async, returns immediately with hint to check via list. Ephemeral sandbox cleanup also backgrounded. |
| 2026-09-10 22:42 | v1.2.0 — Reverted shared session DB — SQLite WAL locking fails over Podman bind-mounts. Session DB and state now sandbox-local at /tmp. Removed host bind-mounts for ~/.local/share/goose and ~/.local/state/goose. |
| 2026-09-10 22:30 | v1.1.3 — Fixed session resume: changed 'goose session resume <name>' to 'goose session --resume --name <name>' (correct goose CLI syntax) |
| 2026-09-10 21:17 | v1.1.2 — Fixed interactive session: added --tty to sandbox exec for session command (PTY allocation for terminal input). One-shot run uses --no-tty to avoid hang on exit. |
| 2026-09-10 19:52 | v1.1.1 — Added sandbox user (UID 1000) to Containerfile — eliminates 'cannot find name for user ID 1000' warning. Fixed slow ephemeral sandbox delete by using trap-aware sleep in keep-alive process. Image rebuilt and pushed to quay.io/rhtevan/agentbox-goose-shim:latest. |
| 2026-09-10 19:18 | v1.1.0 — Relocated Containerfile, policy.yaml, goose-sandbox into skill directory (factory pattern). setup.sh installs goose-sandbox to ~/.local/bin/ and policy to ~/.config/openshell/. build.sh supports --push for OCI registry. teardown.sh removes installed artifacts. All paths updated to installed locations. |
| 2026-09-10 17:39 | v1.0.1 — Fixed verify.sh set -e early exit. Added session DB and state dir bind-mounts. Wrapper copies config to /tmp for write access. ANSI color stripping in sandbox phase detection. |
| 2026-09-10 16:03 | v1.0.0 — Initial skill: setup, build, configure, verify, teardown for Goose CLI sandboxing under NVIDIA OpenShell. Fedora shim image (Containerfile), network policy (policy.yaml), goose-sandbox wrapper CLI. verify.sh S1–S10 live sandbox testing. Validated: UID mapping (keep-id), SSRF exemption, inference round-trip. |
