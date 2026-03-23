# Connecting Claude to Your Vault

Your vault is designed to work with Claude as the AI agent. Here's how to connect them.

---

## Option 1 — Claude Code (Recommended)

Claude Code is a terminal-based agent that can read and write files in your vault directly.

**Install:**
```bash
npm install -g @anthropic-ai/claude-code
```

**Use:**
```bash
cd ~/Brain          # your vault root
claude              # starts a session
```

Claude reads `CLAUDE.md` automatically when you open the vault directory. This file tells it where the agent instructions live and how to start a session.

On your first session, it will run the `BOOTSTRAP.md` protocol.

---

## Option 2 — Claude Cowork

Claude Cowork is a desktop app for non-developers. It connects to your vault folder and operates the same way as Claude Code.

Download at: https://claude.ai/download

Open the app → Connect a folder → Select your vault root (`~/Brain` or wherever you put it).

---

## Option 3 — Claude.ai (Manual)

If you don't want to install anything, you can use Claude.ai directly. The trade-off is that it can't read/write files automatically — you copy and paste.

**For a session:**
1. Open Claude.ai
2. Start with: "I'm going to share my vault files. Please read them before we start."
3. Paste the contents of `CLAUDE.md`, `06-Agent/workspace/AGENTS.md`, and `06-Agent/workspace/USER.md`
4. Then tell it what you want to work on

This works but loses the automation and file-writing capabilities.

---

## How the agent knows what to do

When Claude opens your vault, it reads files in this order:

1. `CLAUDE.md` — the entry point, tells it where everything is
2. `06-Agent/workspace/AGENTS.md` — the operating instructions
3. `06-Agent/workspace/SOUL.md` — tone and personality
4. `06-Agent/workspace/USER.md` — your profile
5. `06-Agent/workspace/memory.md` — long-term context
6. Today's memory log — what happened recently
7. Specialist briefings — `06-Agent/subagents/*/briefing.md` (CRM follow-ups, calendar context)
8. Vault health + pending actions — `06-Agent/workspace/vault-health.md` and `pending-actions.md`
9. Inbox check — item count, flags if overloaded
10. Day type detection — determines which greeting format to use (Monday, regular, Friday, quarterly, quarter kickoff)

This happens every session. The agent has no memory between sessions — the files *are* the memory.

---

## Scheduled jobs (optional)

The vault includes cron jobs for daily briefings, inbox sweeps, and weekly reviews. These require the Claude CLI and run automatically on macOS via launchd.

**Activate:**
```bash
bash ~/Brain/06-Agent/cron/install-jobs.sh
```

**Check status:**
```bash
launchctl list | grep com.brain
```

**Jobs installed:**
- `07:30` daily — morning briefing written to your daily note
- `07:15` daily — context pack rebuild (CONTEXT-PACK.md)
- `18:00` weekdays — end-of-day summary to agent memory
- `10:00` weekdays — inbox sweep suggestions
- `21:00` nightly — CRM scan (contact detection, last-contact updates, briefing refresh)
- `21:30` nightly — pattern check (recurring carries, stale actions, open loops)
- `Sunday 20:00` — vault health check (hygiene score, stale projects, inbox health)
- `Friday 17:00` — weekly review draft

Logs live in `06-Agent/cron/logs/`.

---

## Troubleshooting

**Agent seems to have forgotten context**
It's a fresh instance every session. Make sure it's reading the workspace files. Ask: "Have you read AGENTS.md and USER.md?" If not, point it to them.

**Agent is writing to the wrong places**
Check `05-Meta/conventions.md` — this is the filing rulebook. If the agent keeps getting it wrong, it may need to re-read that file.

**Something in AGENTS.md needs changing**
Either edit it directly, or tell the agent what you want to change and ask it to propose an update. It will show you the diff before writing.

**Want to reset onboarding**
Recreate `06-Agent/workspace/BOOTSTRAP.md` from the template in the portable-brain repo. The agent will run the 3-session protocol again on next open.
