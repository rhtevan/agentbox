# Directory Update Log

<!-- Append-only. Newest entries at top. -->

## 2026-09-11 10:26

- Updated docs/test-report.md: added step-by-step test procedures for T1–T9 and N1–N6 with exact commands, expected output, and cleanup steps (286 lines added). Committed and pushed to rhtevan/agentbox.

## 2026-09-11 09:45

- Wind-down documentation phase (D1–D5): created README.md (workshop-style, 6 labs), docs/requirements.md (goals G1–G7), docs/design.md (decisions D1–D8, security boundaries), docs/implementation.md (skill stack, policy, config reference), docs/test-report.md (S1–S10, T1–T9, 13 issues, negative tests). GitHub Pages scaffolding: _config.yml (Cayman theme), assets/css/style.scss, .gitignore updated. Archify diagrams: sandbox-architecture (architecture), sandbox-lifecycle (lifecycle), sandbox-egress (sequence) — all showcase-validated and delivered to docs/.

## 2026-09-11 08:45

- Reverted default SHIM_IMAGE to localhost/goose-shim:latest — eliminates disconnect between build.sh (local) and wrapper (remote). Push to registry remains opt-in via build.sh --push.

## 2026-09-11 08:40

- Changed default SHIM_IMAGE from localhost/goose-shim:latest to quay.io/rhtevan/agentbox-goose-shim:latest. All scripts updated. Works without local build — pulls from registry on first run.

## 2026-09-10 23:10

- Added bash completion for goose-sandbox and gs alias. Setup installs completion to ~/.local/share/bash-completion/completions/ and adds 'gs' alias to ~/.bashrc. Teardown removes both. Session resume now shows conversation history (--history flag).

## 2026-09-10 23:06

- Added --history flag to session resume — shows previous messages when reconnecting to a sandbox session.

## 2026-09-10 23:01

- Fixed trailing comma in driver-config-json that caused sandbox creation to fail silently.

## 2026-09-10 22:53

- Background delete: sandbox delete runs async, returns immediately with hint to check via list. Ephemeral sandbox cleanup also backgrounded.

## 2026-09-10 22:42

- Reverted shared session DB — SQLite WAL locking fails over Podman bind-mounts. Session DB and state now sandbox-local at /tmp. Removed host bind-mounts for ~/.local/share/goose and ~/.local/state/goose.

## 2026-09-10 22:30

- Fixed session resume: changed `goose session resume <name>` to `goose session --resume --name <name>` (correct goose CLI syntax).

## 2026-09-10 21:32

- Added Rule 18 (Pre-Flight Checklist) to AGENTS.md: write action plan before multi-step changes, review against rules, execute in order. Synced AGENTS.md template v5.8.0 → v5.9.0. Combats multi-turn discipline decay.

## 2026-09-10 21:17

- Updated goose-openshell v1.1.2: Fixed interactive session TTY allocation (--tty for session, --no-tty for run).

## 2026-09-10 19:52

- Updated goose-openshell v1.1.1: Added sandbox user to Containerfile, trap-aware sleep for fast delete. Image pushed to quay.io/rhtevan/agentbox-goose-shim:latest.

## 2026-09-10 19:18

- Updated goose-openshell v1.1.0: Factory pattern — skill owns source artifacts, setup.sh installs to standard locations (~/.local/bin/goose-sandbox, ~/.config/openshell/goose-policy.yaml). build.sh supports --push. Callable from any project directory.

## 2026-09-10 17:48

- goose-openshell CHANGELOG.md: normalized to table format (was hybrid heading+table).
- Synced AGENTS.md template (project scope).

## 2026-09-10 17:39

- Updated goose-openshell v1.0.1: verify.sh fixed set -e exit, added session DB and state bind-mounts (S8–S10 live test). goose-sandbox wrapper updated: session DB shared with host via bind-mount, config copied to /tmp for write access.

## 2026-09-10 16:06

- Created goose-openshell v1.0.0: Setup, build, configure, verify, teardown for Goose CLI sandboxing under NVIDIA OpenShell. Fedora shim image, network policy, goose-sandbox wrapper CLI. verify.sh S1–S10 all pass.

## 2026-09-10 14:26

- Synced AGENTS.md template v5.5.0 → v5.8.0 (project scope).

## 2026-09-10 13:59

- Moved fedora-openshell v1.0.0 from USER to PROJECT scope. PROJECT index: 1 skill. Script paths updated to ./.agents/skills/.

## 2026-09-10 13:11

- Created fedora-openshell v1.0.0: install, start, stop, status, upgrade, teardown for NVIDIA OpenShell on Fedora via RPM. verify.sh S1–S9. Originally created at USER scope, moved to PROJECT at 13:59.

## 2026-09-08 15:29

- Added anti-action-sycophancy: SOUL.md identity principle (no acting on assumed inputs) + AGENTS.md Rule 17 (no action on assumed inputs — state missing info, ask, do not execute; flag low confidence at top). Addresses gap exposed by Agentbox weather session hallucination.

## 2026-09-08 10:10

- Created AGENTS.md at project root (scope: project).

## 2026-09-08 10:09

- Initialized .agents/ directory structure (scope: project).
