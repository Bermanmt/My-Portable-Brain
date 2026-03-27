# Scheduled Jobs — Two-Tier Architecture

The vault's background jobs use a **two-tier design** so the system works even when scheduled runs fail (macOS TCC permissions, new machine, portable vault).

## How It Works

**Tier 1 — Pure Bash (auto-refresh)**
These scripts scan vault files and write markdown reports. They need no external dependencies. The agent runs them automatically at session start via `refresh-all.sh` whenever their output is stale.

| Job | Output | Staleness Threshold |
|-----|--------|-------------------|
| daily-briefing | Today's daily note (🤖 section) | 12h |
| crm-scan | `subagents/crm-manager/briefing.md` | 24h |
| pattern-check | `workspace/pending-actions.md` | 24h |
| vault-health | `workspace/vault-health.md` | 48h |
| rebuild-context | `workspace/CONTEXT-PACK.md` | 12h |
| daily-backup | Git commit | 24h |

**Tier 2 — LLM-Dependent (agent compensates)**
These scripts call the `claude` CLI to do LLM work. When cron runs them, great — pre-processed data is ready. When cron doesn't run, the agent detects staleness and does the equivalent work in-session.

| Job | What the agent does instead |
|-----|---------------------------|
| daily-closing | Writes session memory at end of session |
| inbox-sweep | Processes inbox items when user asks or inbox > 20 |
| weekly-review | Runs the Friday planning conversation |

## Session Start Flow

The agent calls `refresh-all.sh` (step 8 in AGENTS.md). This script:
1. Checks each Tier 1 output file's age against its threshold
2. Re-runs stale scripts silently
3. Checks Tier 2 output staleness and prints `AGENT_COMPENSATE:` flags
4. The agent reads those flags and folds the work into the session naturally

Run manually to check status:
```bash
bash 06-Agent/cron/jobs/refresh-all.sh --status   # what's stale?
bash 06-Agent/cron/jobs/refresh-all.sh --force     # refresh everything
bash 06-Agent/cron/jobs/refresh-all.sh             # refresh only stale
```

## Optional: Scheduled Runs (launchd)

For pre-warmed data before you even open a session, install the launchd plists. This is **optional** — the system works without it.

```bash
bash 06-Agent/cron/install-jobs.sh            # install
bash 06-Agent/cron/install-jobs.sh --uninstall # remove
launchctl list | grep brain                    # verify
```

**Known issue (macOS Sequoia+):** launchd blocks `/bin/bash` from accessing `~/Documents/` without Full Disk Access. See roadmap for Option B (wrapper .app bundle). Until then, `refresh-all.sh` is the primary mechanism.

## Logs

Each job appends to `logs/YYYY-MM-DD-jobname.log`. The `refresh-all.sh` wrapper logs to `logs/YYYY-MM-DD-refresh-all.log`.
