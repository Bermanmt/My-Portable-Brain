# Changelog

All notable changes documented here.
Format: [version] — date | Types: Added · Changed · Fixed · Removed

---

## [0.1.0] — 2026-03-11

### Added
- `start.sh` — single entry point with tier selection, dependency check, first mission
- `lib/onboard.sh` — interactive wizard (user profile, roles, themes, agent personality)
- `lib/setup-vault.sh` — full vault structure builder
- Tier 1 (Lean) and Tier 2 (Full) vault options
- `corrections.md` — self-improvement feedback log with 5-rule system
- `BOOTSTRAP.md` — 3-session onboarding protocol
- `LEARN.md` contextual help files for Tier 1 (inbox, projects, areas, core system)
- `docs/philosophy.md` — the why behind the system
- `docs/agent-setup.md` — connecting Claude to your vault
- `docs/decisions/` — architecture decision log
- Scheduled automation via macOS launchd
- Git initialization option in onboarding
- `--dry-run`, `--vault`, `--tier` flags

### Decisions
- Pure bash + markdown only — no Python or databases in v1
- Markdown is always source of truth
- Performance layer (search, classification) deferred to v0.2+

---

## [0.3.0] — 2026-03-26

First "fat" release after v0.1 — bundled ~3 weeks of iteration into one tag. Retroactively documented.

### Added
- **Planning system** — day-aware daily briefing that detects day type (regular / Monday / Friday / quarterly) and adapts content accordingly. Weekly notes auto-created from template. Planning Conversation Protocol added to `AGENTS.md` to guide daily focus, weekly review, and quarterly check conversations.
- **Specialist agent architecture** — CRM manager, calendar agent, inbox processor, researcher, writer — each with their own `AGENT.md`, `briefing.md`, and `processing-log.md`.
- **Vault health + pattern detection** — `vault-health.sh` (score + hygiene report) and `pattern-check.sh` (carries, stale actions, open loops) cron jobs.
- **Task registry** — GTD-context-aware task index with metadata icons (📍⏱🔋📋👤📅). Cron job paths normalized alongside.
- **LLM abstraction** — `06-Agent/config/llm.conf` centralizes model selection so cron jobs can call any configured LLM via a shared `run_llm` function.
- **Git backup cron jobs** — automated daily commit/push of vault changes.
- **Brain CLI wrapper** — `brain <command>` dispatcher (`inbox`, `briefing`, `health`, `backup`, `context`, `cron`).
- **Tier 3 "Minimal"** — lightest-weight vault option. `--minimal` flag on `start.sh`.
- **`--simple` mode** — non-technical installer path that skips tier selection.
- **Session-start script execution** — agent template references `refresh-all.sh` on startup.
- **Landing page + site** — marketing site for the project (with CNAME).
- **Windows installer** — `Install Windows Brain.bat` and `Install Brain.ps1`.
- **macOS installer** — `Install Brain.command` with download instructions.
- **HTML onboarding wizard improvements** — `onboard-wizard.html` refinements.
- **Roadmap document** — `ROADMAP.md` (project-level, not CHANGELOG).

### Fixed
- Cohort 1 portability bugs — `sed`, `date`, Claude CLI flags, `launchctl` compatibility.
- Vault bash command invocation paths.

### Note
This tag is historically messy — it absorbed 22 commits of work that should have been cut as `v0.2.0` partway through. The "v0.2-fixes" and "v0.2: planning system" commits in the log are part of this release.

---

## [0.4.0] — 2026-03-27

### Added
- **`refresh-all.sh`** — single entry point that checks staleness for all Tier 1 cron jobs and re-runs what's needed. Replaces ad-hoc invocation of individual scripts. Prints `AGENT_COMPENSATE:` flags for Tier 2 (LLM-dependent) jobs the agent should fold into the session.
- **`daily-backup.sh`** — dedicated cron job for vault git commits.
- **`templates/cron/README.md`** — documentation for the cron subsystem.

### Changed
- `AGENTS.md` — added session-start refresh step (step 9 in the Session Start Protocol) that invokes `refresh-all.sh`.

---

## [0.5.0] — 2026-04-09

### Added
- **Claude skill for vault setup** — `.claude/skills/setup-brain/SKILL.md` lets Claude Code and Cowork run the onboarding flow end-to-end via a structured skill.
- **`.claude/skills/setup-brain/references/config-schema.md`** — full JSON contract for `onboard.sh --config`, so the skill can generate a `brain-config.json` non-interactively.
- **`--quiet` and `--config` flags on `start.sh`** — non-interactive install mode for skill/automation use.
- **`CLAUDE.md`** — project-level context file so Claude recognizes the repo.

### Changed
- `BOOTSTRAP.md` — now single-session (previously 3-session).
- `start.sh` — major refactor (+112 / -65) to support quiet/config modes alongside interactive.
- `lib/onboard.sh` — honors `--config` JSON input (parsed via `python3`).

---

## [0.6.0] — 2026-04-16

Vault → template sync. Promoted ~6 weeks of live-vault protocol iteration back into the template repo so new installs get the full system.

### Added
- **Cron jobs** — 6 new scripts in `templates/cron/jobs/`:
  - `daily-closing.sh` — LLM-driven end-of-day memory + handoff
  - `inbox-sweep.sh` — LLM-driven inbox triage (delegates to inbox-processor subagent)
  - `weekly-review.sh` — LLM-driven Friday review draft
  - `rebuild-context.sh` — assembles `CONTEXT-PACK.md` single-file context (replaces 7-file reads)
  - `vault-lint.sh` — thin wrapper calling `05-Meta/vault-health.sh`
  - `weekly-tag.sh` — auto-tags each ISO week in git (`YYYY-WNN`)
- **Cron prompts** — new `templates/cron/prompts/` directory with reusable prompt files:
  - `daily-briefing.md`, `daily-closing.md`, `inbox-sweep.md`, `weekly-review.md`, `quarterly-checkin.md`
- **Agent personality layer** — `templates/agent/`:
  - `SOUL.md` — agent identity, tone, values, anti-patterns
  - `IDENTITY.md` — name, emoji, one-liner
  - `TOOLS.md` — tool-usage preferences
  - `USER.md` — user profile (was previously scaffolded during onboarding only)
- **Calendar agent config** — `templates/agent/subagents/calendar-agent/config.md` — calendar priority list, ignore list, query rules, staleness policy
- **Vault conventions** — `templates/meta/conventions.md` — file naming, backlink format, tag taxonomy, filing rules
- **Core System scaffold** — `templates/core-system/` with `README.md`, `roles.md`, `principles.md`, `my-process.md` — the foundation layer above goals
- **Task registry pattern** — expanded `templates/systems/tasks/registry.md` with GTD contexts, metadata icons (📍⏱🔋📋👤📅), and usage guidance

### Changed
- **`templates/agent/AGENTS.md`** — major revision (+179 lines) importing the following protocols from live vault usage:
  - Session Start Protocol — formalized 16-step sequence with fast-start shortcut
  - Planning Conversation Protocol — day-type detection (regular / week_start / planning_day / quarterly_review / quarter_kickoff / ad_hoc) with greeting templates per type
  - Incremental Memory Protocol — write memory as you go, not just at session end (survives crashes)
  - Session End Protocol — handoff file format with Last Session / Open Loops / Proposals Declined / Next Session Context sections
  - Continuity Gap Check — detect missing-day gaps between handoff and today, flag to user instead of assuming stale handoff is fresh
  - Task Registry Protocol — capture rules, situational awareness, registry maintenance, relationship with other vault components
  - CRM real-time people detection — 4 triggers (meeting notes, conversational mentions, meeting prep, recurring meeting enrichment)
  - Specialist Agent Architecture — delegation protocol for CRM manager, calendar agent, inbox processor, researcher, writer
  - Area Maintenance (silent) — STATE/GOALS/RULES file-per-area pattern
- **Subagent AGENT.md files** — refreshed from vault: `crm-manager`, `calendar-agent`, `inbox-processor`, `researcher`, `writer`
- **`lib/onboard.sh`** — patches:
  - `stamp_template` the new `calendar-agent/config.md` (was previously never copied into new vaults)
  - `cp` the `refresh-all.sh` cron job into new vaults (existed in templates since v0.4 but was never installed — AGENTS.md Session Start Protocol step 9 depends on it)
- **Cron comment cleanup** — `pattern-check.sh` and `vault-health.sh` genericized personal agent-name references in comments.

### Fixed
- New installs since v0.4.0 were missing `06-Agent/cron/jobs/refresh-all.sh` despite AGENTS.md depending on it. Now copied during onboarding for all tiers.

### Known Issues / Tech Debt
- `lib/onboard.sh` generates most of the new personality files (SOUL, IDENTITY, USER, TOOLS), the new cron jobs (daily-closing, inbox-sweep, weekly-review, rebuild-context, vault-lint, weekly-tag), conventions, and core-system files via inline heredocs — not by stamping from the new template files. Result: the template files are reference-only on new installs, and only `lib/upgrade.sh` actually uses them (for 4 cron jobs + subagent AGENT.md refresh). Refactor deferred to v0.7.0.

### Decisions
- All references to the agent name use `{{AGENT_NAME}}`; all references to the user use `{{USER_NAME}}`. Vault-specific content (personal goals, CRM contacts, task instances, observations) is intentionally NOT promoted upstream.
- New cron jobs that depend on LLM access (`daily-closing`, `inbox-sweep`, `weekly-review`) ship as bash stubs that shell out to a `run_llm` function defined in `06-Agent/config/llm.conf` — user configures their preferred LLM at onboarding.

---

## [0.7.0] — planned
- Refactor `lib/onboard.sh` to stamp from `templates/` instead of inline heredocs — consolidate the two sources of truth introduced in v0.6.0.
- Tier 1 as a fully distinct lighter structure
- Linux cron support alongside macOS launchd
- Promote `brain update` to a first-class Claude skill (parallel to the bash `lib/upgrade.sh`)
- Claude Skills layer — first-class skills for `daily-close`, `weekly-review`, `inbox-sweep`
- Scheduled tasks via Claude (replacing bash stubs for Tier 2 LLM-dependent jobs)
- Meeting-prep skill with CRM + project context synthesis
