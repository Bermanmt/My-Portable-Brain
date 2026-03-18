# 🧠 My Portable Brain

> A personal knowledge vault powered by Claude. Starts simple. Gets smarter as you use it.

[![Status](https://img.shields.io/badge/status-v0.1-blue.svg)](https://github.com/yourusername/portable-brain)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Requires](https://img.shields.io/badge/requires-bash-lightgrey.svg)]()

---

## What it is

A structured vault for your notes, projects, and knowledge — with an AI agent built in from the start.

One command. A few questions. You get a vault that:
- Knows who you are and how you like to work
- Has a personal AI agent configured to your style
- Organizes around your actual life roles, not generic folders
- Gets more calibrated to you over time through a simple feedback loop

No databases. No Python. No dependencies beyond bash and a Claude session.

---

## Quick start

```bash
git clone https://github.com/Bermanmt/My-Portable-Brain
cd portable-brain
bash start.sh
```

Five minutes of questions, then your vault is ready.

---

## What you get

```
~/Brain/
├── 00-Inbox/               ← everything lands here first
├── 01-Projects/            ← active work with a finish line
├── 02-Areas/               ← ongoing responsibilities
├── 03-Resources/           ← your knowledge base
├── 04-Archive/             ← completed work, never deleted
├── 05-Meta/                ← how the vault works
├── 06-Agent/               ← AI agent runtime
│   └── workspace/
│       ├── AGENTS.md       ← operating instructions
│       ├── USER.md         ← your profile
│       ├── memory.md       ← long-term context
│       └── corrections.md  ← self-improvement log
├── 07-Systems/             ← CRM, goals, planning
└── 08-CoreSystem/          ← your roles, principles, values
```

Plain markdown files. Open in Obsidian, VS Code, or any editor. Works forever.

---

## The agent

Your vault ships with an AI agent configured to your style during setup.

It reads your profile, memory, and operating instructions at the start of every session. It knows who you are, how you like to communicate, what your current projects are, and what your priorities are.

**What it does:**
- Morning briefings written to your daily note
- Weekly review drafts
- Inbox processing with filing suggestions
- Flags when something needs your attention

**What it never does:**
- Move files without showing you first
- Add commitments without asking
- Archive anything without confirmation
- Modify your personal sections in daily notes

### Self-improvement

The agent watches for patterns. When you correct the same thing three times, it asks once if you want to make the change permanent. One suggestion per session, maximum. You can always ask "what are you tracking?" for full transparency.

---

## Two tiers

**Tier 1 — Lean**
Minimal structure. Every folder has a `LEARN.md` explaining why it exists and what goes there. Best if you're new to PARA or want to understand the system as you build it.

**Tier 2 — Full**
Complete vault with all systems pre-built: CRM, finances, goals cascade, weekly reviews, daily notes, scheduled automation. Best if you want everything ready on day one.

Both tiers include the agent and the self-improvement loop.

---

## Requirements

| Requirement | Notes |
|-------------|-------|
| bash 3.2+ | Comes with macOS and Linux |
| git | Optional — for version-controlling your vault |
| Claude CLI | Optional — for scheduled automation |
| Obsidian | Optional — recommended for vault UI |

No Python. No pip. No databases.

---

## Roadmap

### v0.1 (current)
- [x] `start.sh` — single entry point with tier selection
- [x] Interactive onboarding wizard
- [x] Full vault structure (PARA + Agent + Systems + CoreSystem)
- [x] Self-improvement feedback loop (`corrections.md`)
- [x] 3-session `BOOTSTRAP.md` onboarding protocol
- [x] `LEARN.md` contextual help files for Tier 1
- [x] Scheduled automation (macOS launchd)

### v0.2
- [ ] Tier 1 fully distinct from Tier 2
- [ ] Richer skill files for research, writing, coding
- [ ] Linux cron support
- [ ] `--upgrade` flag for existing vaults

### v1.0
- [ ] Tier 3 — systems picker
- [ ] Template library
- [ ] Tested on macOS, Linux, Windows WSL
- [ ] Stable vault structure API

---

## Docs

- [Why this system works](docs/philosophy.md)
- [Connecting Claude to your vault](docs/agent-setup.md)
- [Architecture decisions](docs/decisions/)

---

## Contributing

Issues and discussions welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

V0.x is the right time to reshape things — if something doesn't work or could be better, please open an issue.

---

## License

MIT — do whatever you want with it.

---

<p align="center"><strong>Stop organizing. Start thinking.</strong></p>
