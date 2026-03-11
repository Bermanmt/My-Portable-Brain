# 06-Agent — What This Is

**Your AI agent's home. Don't edit these files manually unless you know why.**

This folder contains everything the agent needs to operate across sessions —
its identity, memory, operating instructions, subagents, and automation.
It lives inside your vault (not hidden) so Obsidian indexes it and backlinks work.

---

## The Key Files

**`workspace/AGENTS.md`** — The agent's operating instructions.
How it starts each session, its safety rules, how it makes decisions,
and the self-improvement protocol. If the agent is behaving oddly,
read this file first.

**`workspace/SOUL.md`** — Personality and tone.
Separate from instructions so you can tune how the agent *feels*
without touching how it *works*. Edit this if you want a different vibe.

**`workspace/USER.md`** — Your profile.
What the agent knows about you. Update this when your role, stack,
or preferences change. The agent reads it every session.

**`workspace/memory.md`** — Long-term memory.
Durable facts that should persist across sessions — standing decisions,
confirmed preferences, key context. The agent appends here; so can you.

**`workspace/memory/YYYY-MM-DD.md`** — Session logs.
One file per day. The agent writes here during and after sessions.
You rarely need to read these — they're for agent continuity, not your reflection.

**`workspace/corrections.md`** — The self-improvement tracker.
Every time you correct the same thing 3 times, the agent notices and asks
if it should change how it works. This file is the tally. Fully auditable.
You can edit or clear any entry at any time.

**`workspace/BOOTSTRAP.md`** — First session protocol.
Exists only during your first 3 sessions. The agent follows a structured
onboarding arc and then deletes this file. Recreate it to restart onboarding.

---

## Subagents

`subagents/` contains specialized agents scoped to specific tasks:
- `inbox-processor/` — sorts inbox items, suggests destinations
- `crm-manager/` — manages contacts and interactions
- `researcher/` — researches topics and files to Resources
- `writer/` — drafts documents and emails

Your main agent orchestrates these. You don't interact with them directly.

---

## Cron Jobs (Optional)

`cron/` contains scheduled automation — daily briefings, weekly review drafts,
inbox sweeps. These are optional. Your vault works fine without them.

To activate: `bash 06-Agent/cron/install-jobs.sh`
Requires the `claude` CLI to be installed and authenticated.

---

## What Not to Touch

Don't manually edit `memory/` files unless you're correcting something wrong.
Don't delete `AGENTS.md` or `SOUL.md` — the agent needs them to start.
Don't restructure this folder — the paths are hardcoded in the agent's instructions.
