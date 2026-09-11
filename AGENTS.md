<!-- agentfs-template-version: 5.9.0 agentfs-scope: project -->
# AGENTS.md — Workspace Entry Point

## Quick Orientation

| Resource | Path | What's Inside |
|----------|------|---------------|
| Agent identity | [.agents/SOUL.md](./.agents/SOUL.md) | Tone, style, communication defaults |
| Skills index | `~/.agents/skills/index.md` | Skill discovery by tags, descriptions, and signal phrases |
| Knowledge index | `~/.agents/knowledge/index.md` | Knowledge discovery by bundle names and concept summaries |
| Directory index | [.agents/index.md](./.agents/index.md) | Full layer listing |
| Activity log | [.agents/log.md](./.agents/log.md) | Reverse-chronological change history |

<!-- Agent identity — inlined by Goose at session start via @import -->
@.agents/SOUL.md

## Scope Definitions

| Scope | Root Path | Purpose |
|-------|-----------|----------|
| **USER** | `~/.agents/` | Machine-wide shared library: skills and knowledge visible across all projects and agents |
| **PROJECT** | `./.agents/` | Per-repository agent workspace: identity, profiles, memories, and project-scoped skills |

### What Lives Where

| Resource | USER (`~/.agents/`) | PROJECT (`./.agents/`) |
|----------|:-------------------:|:----------------------:|
| `skills/` | ✅ shared | ✅ project-specific |
| `knowledge/` | ✅ shared | ❌ never |
| `memories/` | ❌ never | ✅ per-agent |
| `profiles/` | ❌ never | ✅ multi-agent |
| `SOUL.md` | ❌ never | ✅ agent identity |
| `AGENTS.md` | ❌ never | ✅ (at repo root `./`) |
| `index.md` | ✅ | ✅ |
| `log.md` | ✅ | ✅ |

## Discovery Tiers

Context discovery uses a three-tier fallback chain. Execute tiers
in order; stop at the first match. Index files are **active lookup
tools**, not passive documentation — they are the always-available
fallback when frontmatter matching is too narrow and KGM is not
enabled.

| Tier | Mechanism | Source | When |
|------|-----------|--------|------|
| 1 | **Frontmatter match** | Skill descriptions in system prompt | Always available — matched against user message |
| 2 | **Index scan** | `~/.agents/skills/index.md` (tags, descriptions) and `~/.agents/knowledge/index.md` (bundle names, concept summaries) | When Tier 1 finds no match — read the index files, scan for relevant tags/descriptions/concepts |
| 3 | **KGM search** | `search_nodes` tool (knowledge graph extension) | When extension is enabled — query with task topic keywords; read `Source:` files for top results (max 3); summaries alone are insufficient |

- **Tier 2 skill match** → `load_skill` → follow instructions
- **Tier 2 knowledge match** → read the linked concept file(s) before answering
- **No match at any tier** → generic interpretation

## Rules

**All rules below are mandatory.** They are not guidelines,
suggestions, or best-effort. Violating a rule requires explicit
user approval logged with `[OVERRIDE]` per Rule 15. Guardrail
scripts live at `~/.agents/skills/agentfs-setup/scripts/`.

| # | Type | Stimulus | Action |
|---|------|----------|--------|
| | | **Session start** | |
| 1 | Event | Session start | Check for `CLAUDE.md`, `.cursorrules`, `.cursor/rules/`, `.windsurfrules`, `.github/copilot-instructions.md`. Treat as supplementary. `AGENTS.md` wins on conflict. |
| | | **Per-message dispatch** | |
| 2 | Signal | "remember this", "note that", "keep in mind" | → `.agents/memories/MEMORY.md` |
| 3 | Signal | "always do X", "never do Y", "this is a rule" | → Propose as `AGENTS.md` guardrail (human approval) |
| 4 | Signal | "I prefer", "I like", "my style is" | → `.agents/memories/USER.md` |
| 5 | Signal | "forget this", "remove that note" | → Edit `MEMORY.md`, remove entry |
| 6 | Signal | "what do you remember", "check your notes" | → Read `.agents/memories/MEMORY.md` |
| 7 | Signal | "hey git", `git add` | → `load_skill(name: "agentfs-git-push")` — follow completely |
| 8 | Event | User message received | Follow Discovery Tiers (Tier 1 → 2 → 3). Scan this table for stimulus match. Execute matched action. No match at any tier: generic interpretation. |
| | | **Before reading `.agents/`** | |
| 9 | Event | First read of any `.agents/` file in a session | Browse that scope's `index.md` first, follow links to content. |
| | | **Before writing `.agents/`** | |
| 10 | Event | Before destructive op (delete, rename, or edit ≥3 files under `.agents/`) | `~/.agents/skills/agentfs-setup/scripts/checkpoint.sh create <files>` → execute → `checkpoint.sh clear`. |
| 11 | Event | Creating a skill | Default to USER `~/.agents/skills/`. PROJECT only when user explicitly says "project skill" / "for this project" / "local skill". |
| 12 | Event | Writing to `memories/` | PROJECT scope only. Experiences → `MEMORY.md`. Rules → propose `AGENTS.md` guardrail. Preferences → `USER.md`. Mature patterns → graduate to OKF bundle under `~/.agents/knowledge/`. (Rule 13 also fires — this rule is routing, Rule 13 is mechanical.) |
| | | **Before responding** | |
| 13 | Event | Before sending any response | If any write/edit touched `.agents/` or `~/.agents/` this turn: `bash ~/.agents/skills/agentfs-setup/scripts/post-write.sh <file> "<description>" [--version <ver>]` for each modified file (skip `log.md`, `CHANGELOG.md`, auto-generated `index.md`). Do not respond until complete. |
| | | **Always** | |
| 14 | Always | Every response | No validation phrases ("Great question", "Absolutely"). Lead with substance. Name ≥1 risk when evaluating a plan or design. |
| 15 | Always | Every response | No position reversal without new information or logical argument. When reversing, state what changed and previous position. When request conflicts with a rule, quote it, explain, ask for confirmation. Log overrides with `[OVERRIDE]`. |
| 16 | Always | Every response | Session canary name (random, ephemeral). Emit turn 1. ~1-in-5 turns: emit + self-check. Never persist to files. |
| 17 | Always | Every response | **No action on assumed inputs.** When a request requires information the user did not provide and no authoritative source is available: ① State what is missing and why. ② Ask explicitly. ③ Do not call tools, APIs, or produce output that depends on the missing value. When confidence in a claim or result is low, flag it at the top, not buried in a footnote. |
| 18 | Always | Before any multi-step task | **Pre-flight checklist.** Before executing a multi-step change: ① Write an internal action plan listing all steps including process obligations (Rule 13 post-write, changelogs, version bumps, index regen). ② Review the plan against Rules 13–17 — add any missing obligations. ③ Execute steps in planned order. ④ Do not skip ahead or respond before completing all planned steps. This combats multi-turn discipline decay where process obligations are dropped under cognitive load. |

<!-- PROJECT-OWNED sections below. Everything above is template-owned
     and will be overwritten by agentfs-setup --sync. -->

## Agent Profiles

| Agent | Identity | Memories |
|-------|----------|----------|
| default | [SOUL](./.agents/SOUL.md) | [memories/](./.agents/memories/MEMORY.md) |

<!-- SPECKIT START -->
<!-- SPECKIT END -->
