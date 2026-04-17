# Portable Brain

> An opinionated folder structure that gives any LLM instant context on startup. Your second brain — structured for AI, owned by you.

[![Status](https://img.shields.io/badge/status-v0.2-blue.svg)](https://github.com/Bermanmt/My-Portable-Brain)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Requires](https://img.shields.io/badge/requires-bash-lightgrey.svg)]()

---

## What it is

A personal vault that makes any AI assistant immediately useful — not after weeks of training, but from the first session.

One command. A few questions. You get:
- An AI agent that knows who you are, how you work, and what your priorities are
- A planning system that adapts to your week (Monday kickoff, daily focus, Friday review, quarterly rocks)
- A relationship manager that tracks the whole person — not just deals
- Background scripts that keep your vault alive between sessions
- Everything in plain markdown. No databases, no lock-in, no dependencies beyond bash.

**This is the context layer.** It's not an agent framework — it complements Claude, GPT, Cowork, Claude Code, or any LLM you use. Drop it in, and your AI gets you.

---

## Quick start

[Download the latest release](https://github.com/Bermanmt/My-Portable-Brain/releases/latest) (zip), unzip, and run the installer for your platform:

| Platform | What to do |
|----------|-----------|
| **macOS** | Double-click **`Install Brain.command`** |
| **Windows** | Double-click **`Install Windows Brain.bat`** |
| **Linux** | Run `bash install.sh` |

Answer a few questions — your vault is ready in five minutes.

> **macOS:** If blocked, go to System Settings → Privacy & Security → click "Open Anyway"
>
> **Windows:** Requires [Git for Windows](https://git-scm.com/download/win) (the installer will guide you if it's missing)

**Or clone and run directly:**
```bash
git clone https://github.com/Bermanmt/My-Portable-Brain
cd My-Portable-Brain
bash start.sh
```

**Upgrading:** Run `brain update` to get the latest features without losing your personal data.

---

## What you get

```
~/Brain/
├── 00-Inbox/                   ← everything lands here first
│   ├── meetings/               ← meeting notes and transcripts
│   ├── emails/                 ← email captures
│   └── captures/               ← quick captures, screenshots, links
├── 01-Projects/                ← active work with a finish line
├── 02-Areas/                   ← ongoing responsibilities
├── 03-Resources/               ← knowledge base — evergreen reference
├── 04-Archive/                 ← completed or abandoned work
├── 05-Meta/                    ← how the vault works
├── 06-Agent/                   ← AI agent runtime
│   ├── workspace/
│   │   ├── AGENTS.md           ← operating instructions + planning protocol
│   │   ├── SOUL.md             ← agent personality and tone
│   │   ├── USER.md             ← your profile
│   │   ├── memory.md           ← long-term context
│   │   ├── vault-health.md     ← auto-generated hygiene score
│   │   └── pending-actions.md  ← auto-detected patterns and open loops
│   ├── subagents/
│   │   ├── crm-manager/        ← relationship intelligence
│   │   ├── calendar-agent/     ← schedule context for planning
│   │   └── inbox-processor/    ← routes items to the right places
│   └── cron/jobs/              ← background scripts
├── 07-Systems/                 ← CRM, goals, planning cascade
│   ├── CRM/contacts/           ← relationship files
│   └── goals/                  ← daily → weekly → quarterly → yearly
└── 08-CoreSystem/              ← your roles, principles, values
```

Plain markdown files. Works forever.

---

## The planning system

Your agent adapts its greeting based on the day:

| Day | What happens |
|-----|-------------|
| **Monday** | Last week's results, suggested Big 3 with reasoning, project pulse with staleness, calendar, people follow-ups |
| **Tue–Thu** | Big 3 progress, today's schedule, anything needing attention |
| **Friday** | Week review snapshot, then a planning conversation for next week |
| **Quarter end** | Big Rocks status table, area check, then Q+1 planning |
| **Quarter start** | Previous Q final score, new rocks, suggested W1 priorities |
| **Ad-hoc** | Say "let's do a weekly review" any day — agent loads the right context |

The agent suggests priorities based on carries, deadlines, and project staleness — you approve or override.

---

## Specialist agents

Your main agent (the orchestrator) doesn't process raw data. Specialist agents handle their domains and maintain briefing files that the orchestrator reads on startup.

| Agent | What it does |
|-------|-------------|
| **CRM Manager** | Tracks relationships (not just clients). Auto-updates from daily notes. Surfaces follow-ups, birthdays, open loops. |
| **Calendar Agent** | Schedule context for planning. Enriches meetings with vault context (contacts, projects). Detects time crunches. |
| **Inbox Processor** | Routes items to projects, areas, CRM. Flags action items. Relationship-aware. |

Each specialist has:
- `AGENT.md` — instructions and access rules
- `briefing.md` — short summary, rewritten each run (~300-500 tokens)
- `processing-log.md` — append-only audit trail

**Auto-update policy:** silently update interaction logs, preferences, project links, dates. Only flag for user approval: new contacts, contradicting info, archiving.

---

## Background scripts

Cron jobs keep the vault alive between sessions — no LLM needed:

| Script | What it does | Schedule |
|--------|-------------|----------|
| `crm-scan.sh` | Detects contact mentions in daily notes, updates last-contact dates, refreshes CRM briefing | Nightly |
| `vault-health.sh` | Scores vault hygiene (stale projects, inbox health, daily streak, dormant contacts) | Weekly |
| `pattern-check.sh` | Surfaces recurring carries, stale project actions, CRM open loops, unchecked items | Nightly |
| `daily-briefing.sh` | Creates morning note with dashboard stats | Morning |
| `rebuild-context.sh` | Regenerates CONTEXT-PACK.md from vault sources | Morning |

This is the "dumb detection" layer (bash, free, runs overnight). The "smart processing" layer (context extraction, preference updates) happens when the LLM reads the briefings next session.

---

## The CRM

Not a sales CRM — a relationship manager. The same person can be a friend, client, and collaborator:

- Multi-type relationships (friend + client + collaborator on one contact)
- Personal context (birthday, kid's school, gift ideas) alongside professional context (deal stage, project links)
- Auto-updated from daily notes and meetings
- Interaction log with reverse-chronological entries
- Open loops (commitments to people) surfaced in morning briefings

---

## Two tiers

**Tier 1 — Lean:** Minimal structure. Every folder has a `LEARN.md` explaining what goes there. Best for getting started.

**Tier 2 — Full:** Complete vault with all systems pre-built: CRM, goals cascade, scheduled automation, all specialist agents. Best if you want everything on day one.

Both tiers include the agent, planning system, and self-improvement loop.

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| bash 3.2+ | Comes with macOS and Linux |
| git | Optional — for version-controlling your vault |
| Claude / any LLM | The vault is model-agnostic. Works with any AI that reads markdown. |
| Obsidian | Optional but recommended for vault UI |

No Python. No pip. No databases.

---

## Roadmap

### v0.2 (current)
- [x] Interactive onboarding wizard with two tiers
- [x] Planning system: day-type detection, structured greetings, Big 3 cascade
- [x] Specialist agent architecture (CRM, calendar, inbox)
- [x] CRM as relationship manager with auto-updates
- [x] Background scripts (crm-scan, vault-health, pattern-check)
- [x] Vault health scoring and pattern detection
- [x] Quarter kickoff and ad-hoc planning support

### v0.3
- [x] Calendar MCP integration (real calendar data instead of manual input)
- [x] Email agent + email MCP
- [ ] Meeting agent + transcript MCP
- [ ] Notification/nudge system (desktop alerts for planning, follow-ups, birthdays)
- [ ] Linux cron support (currently macOS launchd)

### v1.0
- [ ] Model-agnostic agent runner (run specialists on any LLM provider)
- [ ] Brain modules (users pick "Relationships", "Schedule", etc. during onboarding)
- [ ] House Manager and Financial Manager agents
- [ ] Calendar write mode (time blocking, meeting auditing)
- [ ] Tested on macOS, Linux, Windows WSL

---

## Docs

- [Why this system works](docs/philosophy.md)
- [Connecting your AI to the vault](docs/agent-setup.md)
- [Architecture decisions](docs/decisions/)

---

## Contributing

Issues and discussions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

This is early — if something doesn't work or could be better, please open an issue.

---

## License

MIT — do whatever you want with it.

---

<p align="center"><strong>Stop organizing. Start thinking.</strong></p>
