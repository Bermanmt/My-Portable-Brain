# Portable Brain

> An opinionated folder structure that gives any LLM instant context on startup. Your second brain — structured for AI, owned by you.

[![Status](https://img.shields.io/badge/status-v0.6.1-blue.svg)](https://github.com/Bermanmt/My-Portable-Brain)
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

## Why it matters

**They say humans use 10% of their brain.** Your portable brain uses ~1.4% per session — and that's the point.

A mature vault holds a million tokens of accumulated context (memory, projects, people, decisions, patterns). Without curation, every session burns tokens on the LLM crawling your folder trying to figure out what's relevant. The Brain pre-distills everything in cron — for free — so the LLM only sees the right ~1.4% per session, already curated.

This solves three things at once:

1. **Your AI actually remembers.** Not just within a session — across sessions, across surfaces, across months. The Brain writes session memory, tracks patterns silently, and surfaces relevant past context when you reference it ("what did we decide about X three weeks ago?").
2. **It notices things you didn't.** Topics that have come up three times across different sessions. People you keep mentioning who aren't in your CRM. Patterns in your week. Surfaced when relevant, not as a lecture.
3. **It saves you tokens.** A typical session loads ~20k tokens of curated context instead of the LLM exploring 80–150k looking for relevance. The "I run out of tokens too fast" pain disappears.

Built around three architectural commitments: **the Brain owns meaning, apps own state · cron searches, LLM thinks · adapters are additive, never subtractive.** Works with Claude, GPT, Gemini, anything that reads markdown.

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

The roadmap is now organized around the three memory aha moments. Full plan in [`ROADMAP.md`](ROADMAP.md).

### v0.6 (current)
- [x] Interactive onboarding wizard with three tiers (Lean / Full / Minimal)
- [x] Planning system: day-type detection, structured greetings, Big 3 cascade
- [x] Specialist agent architecture (CRM, calendar, inbox, researcher, writer)
- [x] CRM as relationship manager with auto-updates
- [x] Background scripts (crm-scan, vault-health, pattern-check, refresh-all, daily-backup)
- [x] LLM-driven cron jobs (daily-closing, inbox-sweep, weekly-review, rebuild-context)
- [x] Vault health scoring and pattern detection
- [x] Quarter kickoff and ad-hoc planning support
- [x] Agent personality layer (SOUL, IDENTITY, USER, TOOLS) and Core System scaffold
- [x] Task registry with GTD contexts and metadata
- [x] Claude skill for vault setup (`.claude/skills/setup-brain/`)
- [x] Safe update infrastructure (`update-brain` Claude skill, `VERSION` markers, 3-way merge for AGENTS.md)

### v0.8 — Memory Experience (next)
- [ ] **Memory retrieval layer** — ranked search across memory, observations, daily notes, CRM, project files. Delivers "it found what I said 3 weeks ago."
- [ ] **Pattern surfacing upgrade** — Pepe references relevant patterns mid-conversation, not just at Friday review.
- [ ] **Cross-session continuity primitive** — `06-Agent/state/inbound/` staging folder + absorption protocol; preps for cross-surface continuity.

### v0.9 — Onboarding That Delivers the Aha Fast
- [ ] Replace 15-question flow with first-capture hook ("What's on your mind right now?")
- [ ] First aha within 5 minutes — first session references the capture back with context
- [ ] Bootstrap single-session rewrite
- [ ] `brain-onboard` Claude skill alongside `start.sh`
- [ ] Surface the compression ratio in the first-session greeting (the "1.4%" hook)

### v1.0 — Context Transport MCP + Schema (the launch tag)
- [ ] **Context Transport MCP v0.1** — three tools: `get_context`, `search_memory`, `push_session`. Stdio transport. Brain stays authoritative; remote surfaces push summaries, never edit files directly.
- [ ] `RingFilter` class — ring-based access control built in from day one (defense in depth).
- [ ] `weekly-review.sh` generator — Friday payoff against current task format.
- [ ] **Task Schema v1** — minimal required fields (`id` + `area`); shadow-mode migration for 2 weeks.
- [ ] **`brain stats` command** — surfaces compression ratio + discovery tax estimate. Launch-defining artifact.
- [ ] **Launch benchmark** — controlled experiment (Brain vs. no-Brain, same task, measured tokens) published as `launch/benchmark-results-YYYY-MM.md`.

### v1.1 — Workflow Plumbing
- [ ] Reminders ↔ Brain sync (Mac first, Linux/Windows adapters later)
- [ ] **Meeting Notes Protocol** — 7-stage processing pipeline that turns any transcript (Google Meet + Gemini, Fathom, Otter, manual) into CRM updates, project decisions, tasks, and indexed memory. Spec: `specs/meeting-notes-protocol.md`. Memory multiplier.
- [ ] Monthly + quarterly review generators
- [ ] `brain-cron` CLI + `schedule.yaml` (single-source-of-truth scheduler with platform adapters)

### v1.2 — Cross-Surface Reach
- [ ] HTTP transport on MCP + Tailscale tunnel
- [ ] Claude Web + Mobile pull/push via the same three MCP tools
- [ ] Ring filter enforced at HTTP transport boundary

### v1.3 — Integrations
- [ ] Apple Calendar (CalDAV) MCP connector
- [ ] Meeting notes adapters: Google Meet + Gemini (via Calendar `attachments[]` + Drive), Fathom, Otter
- [ ] Email agent + Gmail/IMAP MCP
- [ ] Notification system (actionable only)

### v2.0 — Platform & Modules
- [ ] Brain modules (users pick "Relationships", "Schedule", "Finance", etc. during onboarding)
- [ ] Model-agnostic agent runner (Claude / GPT / Ollama provider adapters)
- [ ] House Manager and Financial Manager specialists
- [ ] Calendar write mode (time blocking, meeting auditing)
- [ ] Tested on macOS, Linux, Windows WSL
- [ ] Vault OTA updates for system files (never touches user data)

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
