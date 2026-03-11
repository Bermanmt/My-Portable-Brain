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

## [0.2.0] — planned
- Tier 1 as a fully distinct lighter structure
- Richer skill files (research, writing, coding)
- Linux cron support alongside macOS launchd
- `--upgrade` flag for existing vaults
